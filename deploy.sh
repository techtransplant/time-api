#!/usr/bin/env bash
# This is a fairly robust deployment script for the time-api project.
# I used claude to generate some of the fancy stuff like the spinner and colors :)
set -e

# Colors and formatting
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Function for spinner animation
spinner() {
  local pid=$1
  local delay=0.1
  local spinstr='|/-\'
  while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
    local temp=${spinstr#?}
    printf " [%c]  " "$spinstr"
    local spinstr=$temp${spinstr%"$temp"}
    sleep $delay
    printf "\b\b\b\b\b\b"
  done
  printf "    \b\b\b\b"
}

# Function to display step headers
step() {
  echo -e "\n${BLUE}${BOLD}==>${NC}${BOLD} $1${NC}"
}

# Function to check if the endpoint is available
check_endpoint() {
  local url=$1
  local max_attempts=$2
  local wait_time=$3
  local attempt=1

  echo -e "${YELLOW}Waiting for endpoint to become available...${NC}"

  while [ $attempt -le $max_attempts ]; do
    echo -n "Attempt $attempt/$max_attempts: "
    local status_code=$(curl -s -o /dev/null -w "%{http_code}" http://$url || echo "000")

    if [ "$status_code" = "200" ]; then
      echo -e "${GREEN}SUCCESS${NC}"
      return 0
    elif [ "$status_code" = "000" ]; then
      echo -e "${YELLOW}Connection refused${NC}"
    else
      echo -e "${YELLOW}Received status code: $status_code${NC}"
    fi

    if [ $attempt -lt $max_attempts ]; then
      echo -n "Waiting ${wait_time}s before next attempt... "
      sleep $wait_time
      echo "done."
    fi

    attempt=$((attempt+1))
  done

  echo -e "${YELLOW}Maximum attempts reached. The endpoint might not be fully ready yet.${NC}"
  return 1
}

# Parse command line arguments
AUTO_APPROVE=false
REGION=""

while [[ $# -gt 0 ]]; do
  case $1 in
    -y|--yes|--auto-approve)
      AUTO_APPROVE=true
      shift
      ;;
    -r|--region)
      REGION="$2"
      shift 2
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Usage: $0 [-y|--yes|--auto-approve] [-r|--region AWS_REGION]"
      exit 1
      ;;
  esac
done

# Set up auto-approve flag if requested
TF_APPROVE=""
if [ "$AUTO_APPROVE" = true ]; then
  TF_APPROVE="-auto-approve"
fi

# Apply region if specified
if [ ! -z "$AWS_DEFAULT_REGION" ]; then
  export TF_VAR_aws_region="$AWS_DEFAULT_REGION"
  echo -e "${YELLOW}Using AWS region: $AWS_DEFAULT_REGION${NC}"
fi

# Check for required tools
for cmd in terraform docker aws git curl; do
  if ! command -v $cmd &> /dev/null; then
    echo -e "${RED}Error: $cmd is required but not installed.${NC}"
    exit 1
  fi
done

# Check AWS credentials
if ! aws sts get-caller-identity &> /dev/null; then
  echo -e "${RED}Error: AWS credentials not found or invalid.${NC}"
  echo -e "Make sure you have the AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_SESSION_TOKEN (if needed) environment variables set."
  exit 1
fi

# Generate a tag using git commit hash
if git rev-parse --git-dir > /dev/null 2>&1; then
  IMAGE_TAG=$(git rev-parse --short HEAD)
else
    # Fallback to a timestamp if .git is not found
    IMAGE_TAG=$(date +%Y%m%d%H%M%S)
fi
echo -e "${YELLOW}Using image tag: ${BOLD}$IMAGE_TAG${NC}"

# Move to infra directory
cd infra

# Initialize terraform if needed
if [ ! -d ".terraform" ]; then
  step "Initializing Terraform"
  terraform init
fi

# Create ECR repository first
step "Creating ECR repository"
terraform apply -target=aws_ecr_repository.time_api $TF_APPROVE

# Get the ECR repository URL
ECR_REPO=$(terraform output -raw ecr_repository_url)
echo -e "${GREEN}ECR Repository URL: ${BOLD}$ECR_REPO${NC}"

# Move back to root directory to build the Docker image
cd ..

# Build and push Docker image
step "Building Docker image"
docker build --platform=linux/amd64 -t time-api -f api/Dockerfile api/ &
PID=$!
spinner $PID
wait $PID

step "Authenticating with ECR"
cd infra
aws ecr get-login-password --region $(terraform output -raw aws_region 2>/dev/null || echo ${TF_VAR_aws_region:-us-west-2}) | \
  docker login --username AWS --password-stdin $ECR_REPO
cd ..

step "Pushing image to ECR"
echo -e "Tagging as: ${BOLD}$ECR_REPO:$IMAGE_TAG${NC}"
docker tag time-api:latest $ECR_REPO:$IMAGE_TAG
docker push $ECR_REPO:$IMAGE_TAG &
PID=$!
spinner $PID
wait $PID

# Deploy the infrastructure with the specific image tag
step "Deploying infrastructure"
cd infra
if [ "$AUTO_APPROVE" = true ]; then
  echo -e "${YELLOW}Auto-approving all changes${NC}"
fi
terraform apply -var="image_tag=$IMAGE_TAG" $TF_APPROVE

# Get endpoint info
ALB_DNS=$(terraform output -raw alb_dns_name)

echo -e "\n${GREEN}${BOLD}Deployment complete!${NC}"
echo -e "${BLUE}API endpoint:${NC} http://$ALB_DNS"
echo -e "${BLUE}Deployed image:${NC} $ECR_REPO:$IMAGE_TAG"

# Check ECS task status
step "Checking ECS task status"
echo -e "Waiting for ECS task to start and register with the load balancer..."
CLUSTER_NAME=$(terraform output -raw ecs_cluster_name 2>/dev/null || echo "time-api-cluster")
SERVICE_NAME=$(terraform output -raw ecs_service_name 2>/dev/null || echo "time-api-service")
REGION=$(terraform output -raw aws_region 2>/dev/null || echo ${TF_VAR_aws_region:-us-west-2})

# Wait for the service to stabilize
aws ecs wait services-stable --cluster $CLUSTER_NAME --services $SERVICE_NAME --region $REGION

# Check if endpoint is responding
step "Checking if API endpoint is responding"
check_endpoint $ALB_DNS 10 15

echo -e "\n${GREEN}${BOLD}Deployment verification complete!${NC}"
echo -e "${BLUE}API endpoint:${NC} http://$ALB_DNS"

# Test the endpoint
step "Testing the endpoint"
echo -e "Running a test curl command:"
curl http://$ALB_DNS || echo -e "\n${YELLOW}Endpoint may not be fully ready. Try again in a few minutes.${NC}"

echo -e "\n${YELLOW}To clean up all resources, run: ./destroy.sh${NC}"
