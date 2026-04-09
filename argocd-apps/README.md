# ArgoCD App of Apps

This directory contains the ArgoCD App of Apps setup for deploying the EKS demo microservices.

## Structure

```
argocd-apps/
├── root-app.yaml       # Root Application (App of Apps) - bootstrap this first
├── apps/               # ArgoCD Application manifests (child apps)
│   ├── auth.yaml
│   ├── backend.yaml
│   └── frontend.yaml
└── charts/             # Helm 3 charts for each service
    ├── auth/           # Auth service + MongoDB StatefulSet
    ├── backend/        # Backend service + PostgreSQL + Liquibase migrations
    └── frontend/       # Frontend React app + Nginx + Gateway API route
```

## Apps Overview

| App      | Namespace | Components                                           |
|----------|-----------|------------------------------------------------------|
| **auth** | `auth`    | Auth service (Rust), MongoDB StatefulSet             |
| **backend** | `backend` | Backend service (Rust), PostgreSQL StatefulSet, Liquibase migrations |
| **frontend** | `frontend` | React app + Nginx, Gateway API HTTPRoute with TLS  |

## Network Policies

- **Default deny** ingress in all namespaces
- **Frontend** → Backend (8080) and Auth (8080) allowed
- **Backend** → PostgreSQL (5432) allowed
- **Auth** → MongoDB (27017) allowed
- DNS egress allowed for cluster discovery

## Quick Start

### Prerequisites

1. ArgoCD installed on the cluster
2. `kubectl` configured for the EKS cluster
3. Images built and pushed to Docker Hub (`andygolubev/eks-demo-*`)
4. Gateway API CRDs and the shared `argocd-gateway` already installed in the cluster

### Bootstrap App of Apps

```bash
kubectl apply -f https://raw.githubusercontent.com/andygolubev/eks-and-friends/main/argocd-apps/root-app.yaml
```

ArgoCD will create the root Application, which in turn creates the three child Applications (auth, backend, frontend). Each child app deploys its Helm chart to its respective namespace with auto-sync enabled.

### Get ArgoCD Password

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
```

## Image Tags

Charts reference images by version tag (e.g. `v0.0.1` or `sha-abc1234`). Tags are updated by the GitHub Actions CI when images are built. See `.github/workflows/build-images.yml`.

## Customization

- **Image registry/tag**: Edit `values.yaml` in each chart under `charts/<app>/`
- **Frontend hostname**: `charts/frontend/values.yaml` → `gateway.hostname`
- **Frontend Gateway**: `charts/frontend/values.yaml` → `gateway.name` / `gateway.namespace`
- **Frontend TLS**: Managed on the shared Gateway listener, not in the frontend chart
- **Replicas, resources**: `values.yaml` per chart

## Sync Behavior

- **Root app**: Syncs `apps/` directory (the three Application manifests)
- **Child apps**: Sync their Helm chart with `automated: prune, selfHeal`
- **Backend**: Runs Liquibase migrations as a PreSync hook before app deployment
