#!/usr/bin/env bash

set -euo pipefail

# Creates an S3 bucket for Terraform state in the given AWS region, with server-side encryption and versioning.
# Usage:
#   AWS_REGION=us-west-2 TF_STATE_BUCKET=my-tf-state-bucket ./scripts/create-tf-state-bucket.sh
# Optional:
#   TF_STATE_REGION overrides AWS_REGION for bucket location if set
#   AWS_PROFILE can be used to select a credentials profile

AWS_REGION_ENV_VALUE="${AWS_REGION:-us-east-1}"
TF_STATE_REGION_ENV_VALUE="${TF_STATE_REGION:-us-east-1}"
BUCKET_NAME="${TF_STATE_BUCKET:-eks-argo-terraform-tf-state-bucket}"

if [[ -z "${AWS_REGION_ENV_VALUE}" && -z "${TF_STATE_REGION_ENV_VALUE}" ]]; then
  echo "ERROR: AWS_REGION or TF_STATE_REGION must be set" >&2
  exit 1
fi

REGION="${TF_STATE_REGION_ENV_VALUE:-${AWS_REGION_ENV_VALUE}}"

if [[ -z "${BUCKET_NAME}" ]]; then
  echo "ERROR: TF_STATE_BUCKET must be set (matches terragrunt remote_state.config.bucket)" >&2
  exit 1
fi

echo "Using region: ${REGION}"
echo "Bucket name: ${BUCKET_NAME}"

# Determine the correct LocationConstraint payload. us-east-1 is special and must omit LocationConstraint.
CREATE_BUCKET_ARGS=("s3api" "create-bucket" "--bucket" "${BUCKET_NAME}" "--region" "${REGION}")
if [[ "${REGION}" != "us-east-1" ]]; then
  CREATE_BUCKET_ARGS+=("--create-bucket-configuration" "LocationConstraint=${REGION}")
fi

echo "Creating bucket if not exists..."
if aws s3api head-bucket --bucket "${BUCKET_NAME}" 2>/dev/null; then
  echo "Bucket already exists and is accessible: ${BUCKET_NAME}"
else
  aws "${CREATE_BUCKET_ARGS[@]}"
  echo "Bucket created: ${BUCKET_NAME}"
fi

echo "Enabling default encryption (SSE-S3)..."
aws s3api put-bucket-encryption \
  --bucket "${BUCKET_NAME}" \
  --server-side-encryption-configuration '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

echo "Enabling versioning..."
aws s3api put-bucket-versioning --bucket "${BUCKET_NAME}" --versioning-configuration Status=Enabled

echo "Blocking public access..."
aws s3api put-public-access-block \
  --bucket "${BUCKET_NAME}" \
  --public-access-block-configuration BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true

cat <<EOF

Done.

Export these for terragrunt if you haven't already:
  export TF_STATE_BUCKET=${BUCKET_NAME}
  export TF_STATE_REGION=${REGION}

If using Terraform 1.10+ S3 backend with native locking, set in backend config:
  use_lockfile = true

EOF


