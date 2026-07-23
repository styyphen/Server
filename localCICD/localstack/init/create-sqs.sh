#!/usr/bin/env bash
set -euo pipefail

awslocal sqs create-queue --queue-name local-dev-events >/dev/null
awslocal sqs create-queue --queue-name local-dev-deadletters >/dev/null

echo "LocalStack SQS queues are ready."
