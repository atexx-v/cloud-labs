#!/usr/bin/env bash
# Після `terraform destroy` і cleanup-task-definitions.sh: перевірка, що в AWS нічого не лишилось.
# Усі лічильники мають бути 0 (бюджет: 1 — він живе окремо і безкоштовний).
set -u
R="${AWS_REGION:-eu-central-1}"
q() { aws "$@" --output text 2>/dev/null || echo "?"; }

printf '%-34s %s\n' "RDS (бази)"              "$(q rds describe-db-instances --region "$R" --query 'length(DBInstances)')"
printf '%-34s %s\n' "Load Balancers"           "$(q elbv2 describe-load-balancers --region "$R" --query 'length(LoadBalancers)')"
printf '%-34s %s\n' "NAT Gateways (активні)"   "$(q ec2 describe-nat-gateways --region "$R" --filter Name=state,Values=pending,available,deleting --query 'length(NatGateways)')"
printf '%-34s %s\n' "Elastic IP"               "$(q ec2 describe-addresses --region "$R" --query 'length(Addresses)')"
printf '%-34s %s\n' "VPC (крім default)"       "$(q ec2 describe-vpcs --region "$R" --filters Name=isDefault,Values=false --query 'length(Vpcs)')"
printf '%-34s %s\n' "ECS кластери"             "$(q ecs list-clusters --region "$R" --query 'length(clusterArns)')"
printf '%-34s %s\n' "ECS task definitions (ACTIVE)" "$(q ecs list-task-definitions --region "$R" --family-prefix cloud-labs --status ACTIVE --query 'length(taskDefinitionArns)')"
printf '%-34s %s\n' "ECR репозиторії"          "$(q ecr describe-repositories --region "$R" --query 'length(repositories)')"
printf '%-34s %s\n' "Secrets Manager"          "$(q secretsmanager list-secrets --region "$R" --query 'length(SecretList)')"
printf '%-34s %s\n' "SNS topics"               "$(q sns list-topics --region "$R" --query 'length(Topics)')"
printf '%-34s %s\n' "CloudWatch alarms"        "$(q cloudwatch describe-alarms --region "$R" --query 'length(MetricAlarms)')"
printf '%-34s %s\n' "CloudWatch dashboards"    "$(q cloudwatch list-dashboards --region "$R" --query 'length(DashboardEntries)')"
printf '%-34s %s\n' "CloudWatch log groups"    "$(q logs describe-log-groups --region "$R" --query 'length(logGroups)')"
printf '%-34s %s\n' "IAM ролі cloud-labs*"     "$(q iam list-roles --query "Roles[?starts_with(RoleName,'cloud-labs')]|length(@)")"
printf '%-34s %s\n' "OIDC providers"           "$(q iam list-open-id-connect-providers --query 'length(OpenIDConnectProviderList)')"
printf '%-34s %s\n' "Budgets (має бути 1)"     "$(q budgets describe-budgets --account-id "$(aws sts get-caller-identity --query Account --output text)" --query 'length(Budgets)')"
