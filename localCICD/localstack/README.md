# LocalStack Starter

LocalStack provides AWS-style services for local development. The init scripts in `init/` are mounted into `/etc/localstack/init/ready.d` by the platform compose file so buckets, queues, and tables are created when LocalStack is ready.

Default endpoint:

```text
http://localhost:4566
```

Useful environment variables for applications:

```text
AWS_ACCESS_KEY_ID=test
AWS_SECRET_ACCESS_KEY=test
AWS_DEFAULT_REGION=us-east-1
AWS_ENDPOINT_URL=http://localhost:4566
```

Run a quick check with the AWS CLI:

```powershell
aws --endpoint-url http://localhost:4566 s3 ls
aws --endpoint-url http://localhost:4566 sqs list-queues
aws --endpoint-url http://localhost:4566 dynamodb list-tables
```
