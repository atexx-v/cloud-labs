#!/bin/sh
# Після `terraform destroy`: прибрати ревізії task definition, які зареєстрував CI.
# Terraform створює лише першу ревізію, а кожен деплой через GitHub Actions додає нову —
# вони лишаються в акаунті після destroy (безкоштовно, але це «залишок», а методичка
# вимагає, щоб destroy прибирав усе).
set -eu

REGION="${AWS_REGION:-eu-central-1}"
FAMILY="${1:-cloud-labs}"

for arn in $(aws ecs list-task-definitions --region "$REGION" --family-prefix "$FAMILY" \
    --status ACTIVE --query 'taskDefinitionArns' --output text); do
  aws ecs deregister-task-definition --region "$REGION" --task-definition "$arn" >/dev/null
  echo "deregistered $arn"
done

inactive=$(aws ecs list-task-definitions --region "$REGION" --family-prefix "$FAMILY" \
  --status INACTIVE --query 'taskDefinitionArns' --output text)
if [ -n "$inactive" ] && [ "$inactive" != "None" ]; then
  # shellcheck disable=SC2086
  aws ecs delete-task-definitions --region "$REGION" --task-definitions $inactive >/dev/null
  echo "deleted inactive revisions"
fi
