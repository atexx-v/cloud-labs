#!/usr/bin/env bash
set -u
R="${AWS_REGION:-eu-central-1}"
q() { aws "$@" --output text 2>/dev/null || echo "?"; }

printf '%-32s %s\n' "RDS databases"              "$(q rds describe-db-instances --region "$R" --query 'length(DBInstances)')"
printf '%-32s %s\n' "Load balancers"           "$(q elbv2 describe-load-balancers --region "$R" --query 'length(LoadBalancers)')"
printf '%-32s %s\n' "NAT gateways (active)"   "$(q ec2 describe-nat-gateways --region "$R" --filter Name=state,Values=pending,available,deleting --query 'length(NatGateways)')"
printf '%-32s %s\n' "Elastic IPs"               "$(q ec2 describe-addresses --region "$R" --query 'length(Addresses)')"
printf '%-32s %s\n' "VPCs (non-default)"       "$(q ec2 describe-vpcs --region "$R" --filters Name=isDefault,Values=false --query 'length(Vpcs)')"
printf '%-32s %s\n' "ECS clusters"             "$(q ecs list-clusters --region "$R" --query 'length(clusterArns)')"
printf '%-32s %s\n' "ECS task definitions (ACTIVE)" "$(q ecs list-task-definitions --region "$R" --family-prefix cloud-labs --status ACTIVE --query 'length(taskDefinitionArns)')"
printf '%-32s %s\n' "ECR repositories"          "$(q ecr describe-repositories --region "$R" --query 'length(repositories)')"
printf '%-32s %s\n' "Secrets Manager"          "$(q secretsmanager list-secrets --region "$R" --query 'length(SecretList)')"
printf '%-32s %s\n' "CloudWatch log groups"    "$(q logs describe-log-groups --region "$R" --query 'length(logGroups)')"
printf '%-32s %s\n' "IAM roles cloud-labs*"     "$(q iam list-roles --query "Roles[?starts_with(RoleName,'cloud-labs')]|length(@)")"
printf '%-32s %s\n' "OIDC providers"           "$(q iam list-open-id-connect-providers --query 'length(OpenIDConnectProviderList)')"
printf '%-32s %s\n' "Budgets (expected: 1)"     "$(q budgets describe-budgets --account-id "$(aws sts get-caller-identity --query Account --output text)" --query 'length(Budgets)')"
