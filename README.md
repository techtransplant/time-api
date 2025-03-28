# time-api
This repo contains the code and infrastructure for a simple API that can be deployed to an AWS account.

## Demo

### Requirements
You will need to have the following tools installed in order to deploy this API to your AWS account:
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) v2.25.5 was used during development, but most recent versions should work.
- [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) v1.11.3 was used during development, but most recent versions should work.
- [Docker](https://docs.docker.com/get-docker/) v28.0.1 was used during development, but most recent versions should work.
- [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) v2.39.5 was used during development, but most recent versions should work.

## Run Locally
You can run the API locally using the following command:
```
make up
```
This will start the API locally using Docker Compose. Upon successful startup, you can access the API at `http://localhost:8000`.

Example:
```
$ make up
[...output snipped for brevity]
✔ Container time-api  Started

$ curl localhost:8000
{"The current epoch time":"1743117154"}

$ docker logs time-api
Server started on port 8000
2025/03/27 23:15:18 "GET http://localhost:8000/ HTTP/1.1" from 192.168.65.1:24218 - 200 39B in 11.666µs
```


## Deploy to AWS
The sections below provide detailed instructions on how to deploy the API to AWS.

### Assumptions
- You have proper credentials, with Admin access, to an AWS account.


### AWS Credentials
You will need to have the following credentials in order to deploy this API to your AWS account:
- `AWS_ACCESS_KEY_ID`
- `AWS_SECRET_ACCESS_KEY`
- `AWS_DEFAULT_REGION` (optional)

## What's Next?
- CORS
- Security
  - Certificate for the ALB, enable HTTPS
- Metrics
- Monitoring
- CI/CD
