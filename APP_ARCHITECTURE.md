# ArgoCD Application Architecture

## Active System (`argocd-apps/`) — EKS Demo Microservices

```
┌─────────────────────────────────────────────────────────────────────┐
│                     TERRAFORM (terraform-module/)                      │
│                                                                       │
│  aws_eks_capability.argocd                                            │
│  ├─ EKS Managed Argo CD (AWS-native)                                  │
│  ├─ AWS IAM Identity Center SSO (RBAC: admin/editor/viewer)           │
│  └─ Cluster admin access policy                                       │
│                                                                       │
│  kubernetes_secret_v1.argocd_local_cluster                            │
│  └─ Registers cluster ARN as "in-cluster" destination                 │
│                                                                       │
│  null_resource.argocd_gitops_bootstrap                                │
│  └─ kubectl applies the root Application manifest                     │
└────────────────────────────┬────────────────────────────────────────┘
                             │ bootstraps
                             ▼
┌─────────────────────────────────────────────────────────────────────┐
│                  ARGOCD NAMESPACE (argocd)                            │
│                                                                       │
│  ┌─────────────────────────────────────────────────────────────┐     │
│  │  Application: root  (App of Apps)                           │     │
│  │  Source: github.com/andygolubev/eks-and-friends.git (main)  │     │
│  │  Path:   argocd-apps/apps/                                   │     │
│  │  Dest:   in-cluster → argocd namespace                       │     │
│  │  Sync:   automated (prune + selfHeal)                        │     │
│  └────────────────────────┬────────────────────────────────────┘     │
│                           │ syncs 3 child Applications               │
│           ┌───────────────┼───────────────┐                          │
│           ▼               ▼               ▼                          │
└───────────┼───────────────┼───────────────┼──────────────────────────┘
            │               │               │
   ┌────────┴──────┐ ┌──────┴──────┐ ┌──────┴──────┐
   ▼               ▼ ▼             ▼ ▼             ▼
┌──────────────────────────────────────────────────────────────────────┐
│                        CHILD APPLICATIONS                             │
│                                                                       │
│  ┌─────────────────┐ ┌──────────────────┐ ┌──────────────────┐       │
│  │ Application:    │ │ Application:     │ │ Application:     │       │
│  │ auth            │ │ backend          │ │ frontend         │       │
│  │                 │ │                  │ │                  │       │
│  │ Helm chart:     │ │ Helm chart:      │ │ Helm chart:      │       │
│  │ charts/auth/    │ │ charts/backend/  │ │ charts/frontend/ │       │
│  │                 │ │                  │ │                  │       │
│  │ Namespace: auth │ │ Namespace:       │ │ Namespace:       │       │
│  │                 │ │ backend          │ │ frontend         │       │
│  │ Auto-sync: ✓    │ │ Auto-sync: ✓     │ │ Auto-sync: ✓     │       │
│  │ CreateNS:  ✓    │ │ CreateNS:  ✓     │ │ CreateNS:  ✓     │       │
│  └────────┬────────┘ └────────┬─────────┘ └────────┬─────────┘       │
│           │                   │                    │                  │
└───────────┼───────────────────┼────────────────────┼──────────────────┘
            │                   │                    │
            ▼                   ▼                    ▼
┌──────────────────────────────────────────────────────────────────────┐
│                       DEPLOYED WORKLOADS                              │
│                                                                       │
│  auth namespace           backend namespace        frontend namespace │
│  ┌──────────────────┐    ┌───────────────────┐    ┌───────────────┐  │
│  │ Auth Service     │    │ Backend Service   │    │ React + Nginx │  │
│  │ (Rust)           │    │ (Rust, port 8080) │    │               │  │
│  │                  │    │                   │    │ Gateway API   │  │
│  │ MongoDB          │    │ PostgreSQL        │    │ HTTPRoute     │  │
│  │ StatefulSet      │    │ StatefulSet       │    │ (TLS)         │  │
│  │                  │    │                   │    │               │  │
│  │                  │    │ sync-wave order:  │    │               │  │
│  │                  │    │ wave 0 → Liquibase│    │               │  │
│  │                  │    │ migrations (Sync  │    │               │  │
│  │                  │    │ hook)             │    │               │  │
│  │                  │    │ wave 1 → Backend  │    │               │  │
│  │                  │    │ Deployment        │    │               │  │
│  └──────────────────┘    └───────────────────┘    └───────────────┘  │
│                                                                       │
│  Network Policies:                                                    │
│    • Frontend ──► Backend:8080, Auth:8080                             │
│    • Backend  ──► PostgreSQL:5432                                     │
│    • Auth     ──► MongoDB:27017                                       │
│    • Default deny ingress in all namespaces                           │
└──────────────────────────────────────────────────────────────────────┘
```

## Production Example (`temp_example-from-working-account/`) — Shared Services

```
┌─────────────────────────────────────────────────────────────────────┐
│                ARGOCD NAMESPACE (argocd)                              │
│                                                                       │
│  AppProjects:                                                         │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │ default         — wildcard access, argocd source namespace   │    │
│  │ shared-services — scoped to GitLab repos + Helm repos        │    │
│  │                   targets: prowler, sonarqube, cnpg-system   │    │
│  │                   wave 0 (syncs first)                        │    │
│  └──────────────────────────────────────────────────────────────┘    │
│                                                                       │
│  ┌──────────────────────────────────────────────────────────────┐    │
│  │ Application: root (App of Apps)                              │    │
│  │ Source: gitlab.com/.../aws-shared-resources.git (HEAD)       │    │
│  │ Path:   argocd/  (directory recurse)                         │    │
│  │ Include: apps/*.yaml, projects/shared-services.yaml          │    │
│  │ Dest:   in-cluster → argocd namespace                        │    │
│  │ Sync:   automated (prune + selfHeal)                         │    │
│  └───────────────────────────┬──────────────────────────────────┘    │
│                              │                                        │
│        ┌─────────────────────┼──────────────────────┐                 │
│        │                     │                      │                 │
│        ▼ (wave 1)            ▼ (wave 2)             ▼ (wave 3)       │
│  ┌──────────────┐    ┌──────────────┐        ┌──────────────┐        │
│  │ cnpg-operator│    │ prowler      │        │ sonarqube    │        │
│  │              │    │              │        │              │        │
│  │ Helm chart:  │    │ Raw YAML:    │        │Multi-source: │        │
│  │ cloudnative- │    │ argocd/      │        │Helm + values │        │
│  │ pg (0.28.0)  │    │ prowler/     │        │from GitLab   │        │
│  │              │    │              │        │              │        │
│  │ ns: cnpg-    │    │ ns: prowler  │        │ ns: sonarqube│        │
│  │ system       │    │              │        │              │        │
│  │              │    │ retry: 5x    │        │ retry: 10x   │        │
│  │ SSA: ✓       │    │ backoff      │        │ backoff      │        │
│  └──────┬───────┘    └──────┬───────┘        └──────┬───────┘        │
│         │                   │                       │                 │
│         │   ┌───────────────┼───────────────────────┘                 │
│         │   │               │ (wave 2, same wave                      │
│         │   │               │  as prowler)                            │
│         │   │        ┌──────┴───────┐                                 │
│         │   │        │sonarqube-    │                                 │
│         │   │        │infra         │                                 │
│         │   │        │              │                                 │
│         │   │        │Raw YAML:     │                                 │
│         │   │        │sonarqube/    │                                 │
│         │   │        │infra/        │                                 │
│         │   │        │              │                                 │
│         │   │        │Creates ns +  │                                 │
│         │   │        │PG cluster    │                                 │
│         │   │        └──────────────┘                                 │
└─────────┼───┼──────────────┼──────────────────────────────────────────┘
          │   │              │
          ▼   ▼              ▼
┌─────────────────────────────────────────────────────────────────────┐
│                     SHARED SERVICES WORKLOADS                         │
│                                                                       │
│  cnpg-system ns     prowler ns            sonarqube ns                │
│  ┌──────────────┐  ┌──────────────────┐  ┌──────────────────────┐    │
│  │ CNPG Operator│  │ Prowler Scanner  │  │ SonarQube (10.7.0)  │    │
│  │ (CRDs for PG │  │ ├─ API deploy    │  │                      │    │
│  │  clusters)   │  │ ├─ UI deploy     │  │ PostgreSQL Cluster   │    │
│  │              │  │ ├─ Worker deploy │  │ (created by infra    │    │
│  │              │  │ ├─ Beat deploy   │  │  app first)          │    │
│  │              │  │ ├─ PostgreSQL    │  │                      │    │
│  │              │  │ │  Cluster (CNPG)│  │ HTTPRoute (wave 3)   │    │
│  │              │  │ ├─ Valkey        │  │                      │    │
│  │              │  │ └─ HTTPRoute     │  │                      │    │
│  └──────────────┘  └──────────────────┘  └──────────────────────┘    │
└──────────────────────────────────────────────────────────────────────┘
```

## Archive (inactive)

```
archive/argocd/
├── app-of-apps/root.yaml    — old root pointing to eks-argo-terraform repo
├── projects/product.yaml    — product AppProject (old)
└── projects/security.yaml   — security AppProject (old)
```

---

## Key Relationships & Interaction Summary

| Pattern | Detail |
|---|---|
| **Bootstrap** | Terraform (`null_resource.argocd_gitops_bootstrap`) applies the **root** Application to the cluster after EKS Managed Argo CD is ready |
| **App of Apps** | **root** Application syncs the `apps/` directory, which contains 3 child Application manifests (auth, backend, frontend) |
| **Helm charts** | Each child app deploys from `charts/<name>/` using Helm with `values.yaml` |
| **Sync ordering** | Backend chart uses `sync-wave` annotations: Liquibase migrations run as a `Sync` hook at wave 0, then the Deployment at wave 1 |
| **In-cluster destination** | All apps use `name: in-cluster` — a Kubernetes secret registering the EKS cluster ARN, set up by Terraform |
| **Production example** | Temp example uses a more advanced pattern: `sync-wave` orchestration across apps (cnpg-operator → prowler/sonarqube-infra → sonarqube), multi-source Helm, and retry backoff |
| **SSO** | Argo CD uses AWS IAM Identity Center with role-based RBAC (admin/editor/viewer groups) |

## Active Applications Detail

### Root Application (`argocd-apps/root-app.yaml`)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: root
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/andygolubev/eks-and-friends.git
    targetRevision: main
    path: argocd-apps/apps
  destination:
    name: in-cluster
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Child Applications

#### Auth (`argocd-apps/apps/auth.yaml`)
- **Source**: `charts/auth/` (Helm chart)
- **Namespace**: `auth`
- **Components**: Auth service (Rust), MongoDB StatefulSet
- **Sync**: automated with CreateNamespace

#### Backend (`argocd-apps/apps/backend.yaml`)
- **Source**: `charts/backend/` (Helm chart)
- **Namespace**: `backend`
- **Components**: Backend service (Rust), PostgreSQL StatefulSet, Liquibase migrations
- **Sync ordering**: 
  - Wave 0: Liquibase migrations (Sync hook with BeforeHookCreation)
  - Wave 1: Backend Deployment

#### Frontend (`argocd-apps/apps/frontend.yaml`)
- **Source**: `charts/frontend/` (Helm chart)
- **Namespace**: `frontend`
- **Components**: React app + Nginx, Gateway API HTTPRoute with TLS

## Terraform Bootstrapping (`08-argocd-capability.tf`)

1. **`aws_eks_capability.argocd`** — Provisions EKS Managed Argo CD with AWS IAM Identity Center SSO integration
2. **`aws_eks_access_policy_association.argocd_cluster_admin`** — Grants cluster admin access to the Argo CD capability role
3. **`kubernetes_secret_v1.argocd_local_cluster`** — Registers the EKS cluster ARN as the `in-cluster` destination so Application manifests don't embed account-specific ARNs
4. **`null_resource.argocd_gitops_bootstrap`** — Applies the root Application via `kubectl` after Argo CD CRDs are ready, bootstrapping the GitOps pipeline
