#!/usr/bin/env bash
set -euo pipefail

if ! awslocal dynamodb describe-table --table-name local-dev-items >/dev/null 2>&1; then
  awslocal dynamodb create-table \
    --table-name local-dev-items \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --key-schema AttributeName=id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST >/dev/null
fi

echo "LocalStack DynamoDB tables are ready."
