#!/usr/bin/env bash
# This script destroys all resources created by this project.
set -e

# Colors and formatting
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Parse command line arguments
AUTO_APPROVE=false

while [[ $# -gt 0 ]]; do
  case $1 in
    -y|--yes|--auto-approve)
      AUTO_APPROVE=true
      shift
      ;;
    *)
      echo -e "${RED}Unknown option: $1${NC}"
      echo "Usage: $0 [-y|--yes|--auto-approve]"
      exit 1
      ;;
  esac
done

# Set up auto-approve flag if requested
TF_APPROVE=""
if [ "$AUTO_APPROVE" = true ]; then
  TF_APPROVE="-auto-approve"
  echo -e "${YELLOW}Auto-approving all deletions${NC}"
else
  echo -e "${RED}${BOLD}WARNING:${NC} This will destroy all resources created by this project."
  echo -e "Type ${BOLD}yes${NC} to confirm:"
  read confirmation
  if [ "$confirmation" != "yes" ]; then
    echo -e "${YELLOW}Destruction cancelled.${NC}"
    exit 0
  fi
fi

# Change to infra directory
cd infra

echo -e "${BLUE}${BOLD}==>${NC}${BOLD} Destroying all resources${NC}"
terraform destroy $TF_APPROVE

echo -e "\n${GREEN}${BOLD}Cleanup complete!${NC}"
echo -e "${YELLOW}All resources have been destroyed.${NC}"
