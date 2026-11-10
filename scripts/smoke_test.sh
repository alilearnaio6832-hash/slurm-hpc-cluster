#!/usr/bin/env bash
# End-to-end check: cluster is up, nodes are idle, a 2-node job runs as a normal user.
set -euo pipefail
cd "$(dirname "$0")/.."

echo "== sinfo =="
docker compose exec -T slurmctld sinfo

echo "== submit hello_cpu as alice =="
jid=$(docker compose exec -T -u alice slurmctld sbatch --parsable --wait /jobs/hello_cpu.sbatch)
echo "job id: ${jid}"

echo "== job output (one line per node) =="
docker compose exec -T slurmctld cat "/shared/hello-cpu-${jid}.out"
