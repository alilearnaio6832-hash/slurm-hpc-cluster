#!/bin/bash
# Starts MUNGE, then either slurmctld (ROLE=controller) or slurmd (ROLE=compute).
set -euo pipefail

ROLE="${ROLE:?ROLE must be 'controller' or 'compute'}"

mkdir -p /run/munge /var/log/munge /var/lib/munge \
         /var/spool/slurmctld /var/spool/slurmd
chown -R munge:munge /run/munge /var/log/munge /var/lib/munge /etc/munge
chown slurm:slurm /var/spool/slurmctld
chmod 755 /var/spool/slurmd

echo "[entrypoint] starting munged"
runuser -u munge -- /usr/sbin/munged

for _ in $(seq 1 20); do
    [ -S /run/munge/munge.socket.2 ] && break
    sleep 0.5
done
[ -S /run/munge/munge.socket.2 ] || { echo "[entrypoint] munged did not start" >&2; exit 1; }

case "$ROLE" in
    controller)
        echo "[entrypoint] starting slurmctld"
        exec runuser -u slurm -- /usr/sbin/slurmctld -D
        ;;
    compute)
        NODE_NAME="${NODE_NAME:-$(hostname -s)}"
        echo "[entrypoint] starting slurmd for node ${NODE_NAME}"
        exec /usr/sbin/slurmd -D -N "${NODE_NAME}"
        ;;
    *)
        echo "[entrypoint] unknown ROLE '$ROLE'" >&2
        exit 1
        ;;
esac
