#!/bin/bash
# deploy-infrastructure.sh - Automated local wrapper for Terraform infrastructure provisioning

set -e

ACTION=${1:-"plan"}
ENVIRONMENT=${2:-"prod"}

# Navigate to terraform directory
cd "$(dirname "$0")/../terraform"

echo "=================================================="
echo " Running Terraform Action: $ACTION "
echo " Environment             : $ENVIRONMENT "
echo "=================================================="

# Ensure terraform is initialized
if [ ! -d ".terraform" ]; then
  echo "Initializing Terraform..."
  terraform init
fi

# Format check and validation
echo "Validating code format and syntax..."
terraform fmt -check || echo "Warning: Code is not formatted. Run: terraform fmt"
terraform validate

case "$ACTION" in
  plan)
    echo "Generating Terraform execution plan..."
    terraform plan -var="environment=$ENVIRONMENT"
    ;;
  apply)
    echo "Applying Terraform configuration changes..."
    terraform apply -var="environment=$ENVIRONMENT" -auto-approve
    ;;
  destroy)
    echo "WARNING: Destroying all provisioned AWS resources..."
    read -p "Are you absolutely sure you want to proceed? (yes/no): " confirm
    if [ "$confirm" = "yes" ]; then
      terraform destroy -var="environment=$ENVIRONMENT" -auto-approve
    else
      echo "Destroy canceled."
    fi
    ;;
  *)
    echo "Error: Invalid action '$ACTION'."
    echo "Usage: ./deploy-infrastructure.sh [plan|apply|destroy] [environment]"
    exit 1
    ;;
esac
