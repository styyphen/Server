#!/usr/bin/env bash
set -euo pipefail

awslocal s3 mb s3://local-dev-artifacts || true
awslocal s3 mb s3://local-dev-uploads || true

echo "LocalStack S3 buckets are ready."
