#!/usr/bin/env bash
set -eu

HOST="${1:?Вкажіть адресу, напр. ./loadtest/run.sh http://<alb-dns> baseline}"
export LT_TAG="${2:-run}"

cd "$(dirname "$0")"
mkdir -p results

locust -f locustfile.py --headless --host "${HOST%/}" --csv "results/$LT_TAG" --only-summary
python3 summary.py "results/$LT_TAG"
