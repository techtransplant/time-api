# time-api
This repo contains the code and infrastructure for a simple API that can be deployed to an AWS account.

## Quick Start
```
# Clone the repo
git clone https://github.com/techtransplant/time-api.git
cd time-api

# Deploy to AWS
make deploy-auto

# Wait about 5-10 minutes...
# Then you should see output similar to this:

Deployment complete!
API endpoint: http://time-api-lb-123456789.us-east-1.elb.amazonaws.com
Deployed image: 123456789.dkr.ecr.us-east-1.amazonaws.com/time-api-repo:558e6aa

==> Checking ECS task status
Waiting for ECS task to start and register with the load balancer...

==> Checking if API endpoint is responding
Waiting for endpoint to become available...
Attempt 1/10: SUCCESS

Deployment verification complete!
API endpoint: http://time-api-lb-123456789.us-east-1.elb.amazonaws.com

==> Testing the endpoint
Running a test curl command:
{"The current epoch time":1743170583}

# When you are finished, destroy everything.
make destroy-auto

# Wait about 5-10 minutes...
Destroy complete! Resources: 34 destroyed.

Cleanup complete!
All resources have been destroyed.
```

### Requirements

The following tools are required to deploy this API to your AWS account:

| Tool | Recommended Version |
|------|---------------------|
| [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html) | v2.25.5 or newer |
| [Terraform](https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli) | v1.11.3 or newer |
| [Docker](https://docs.docker.com/get-docker/) | v28.0.1 or newer |
| [Git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git) | v2.39.5 or newer |

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
{"The current epoch time":1743169434}

$ docker logs time-api
Server started on port 8000
2025/03/27 23:15:18 "GET http://localhost:8000/ HTTP/1.1" from 192.168.65.1:24218 - 200 39B in 11.666µs
```

## Deploy to AWS
The following commands will deploy the API and [34 AWS resources](./infra/main.tf) to your account using Terraform.

**Note: resources will be deployed in the `us-east-1` region by default, unless `AWS_DEFAULT_REGION` is set to a different region. See [infra/variables.tf](./infra/variables.tf) for more details about variables.**

```
make deploy
```
or if you want a hands-off experience,
```
make deploy-auto
```

### Cleanup
When you are done using the API, you can clean up the resources by running the following command:
```
make destroy
```
or if you want a hands-off experience,
```
make destroy-auto
```

### Assumptions
- You have proper AWS credentials, with Admin access, to an AWS account.
- You can run `aws sts get-caller-identity` to verify your credentials.
- You have all of the required software installed and configured.

