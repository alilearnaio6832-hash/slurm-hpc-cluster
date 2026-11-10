# Troubleshooting log

Add an entry every time something breaks. Use this format:

## <short symptom>

- **Symptom:** what you saw (exact error or command output)
- **Cause:** what was actually wrong
- **Fix:** what you changed
- **How I found it:** the commands/logs that led to the cause

---

## Useful commands

```bash
docker compose logs slurmctld          # controller log
docker compose logs c1                 # compute node log
docker compose exec slurmctld sinfo -N -l
docker compose exec slurmctld scontrol show node c1
docker compose exec slurmctld scontrol show job <jobid>
docker compose exec c1 slurmd -C       # real hardware as Slurm sees it
docker compose exec c1 munge -n | docker compose exec -T slurmctld unmunge   # cross-node auth test
```

## Only 2 of 4 cores used with 8 queued 1-core jobs

- **Symptom:** squeue showed 2 running jobs and the rest pending; sinfo showed both nodes "mixed".
- **Cause:** `CR_Core_Memory` without `DefMemPerCPU`: jobs that do not request memory are given all of a node's memory, so a second job cannot fit.
- **Fix:** added `DefMemPerCPU=250` to `configs/slurm.conf`.
- **Result:** 4 jobs run at once (`CPUAlloc=2`, `AllocMem=500` per node). Evidence: `results/03a-queue-before-fix.txt`, `results/03b-queue-after-fix.txt`.

## Container fails to restart after editing slurm.conf

- **Symptom:** `docker compose restart` fails: error mounting slurm.conf, no such file or directory.
- **Cause:** `sed -i` replaced the file (new inode); the single-file bind mount still pointed to the old one.
- **Fix:** `docker compose up -d --force-recreate` after editing the file this way.

## Node `inval`: "gres/gpu count reported lower than configured (0 < 1)"

- **Symptom:** after adding `Gres=gpu:1` to the node and a count-only `gres.conf` (`Name=gpu Count=1`), the node went `inval` and `slurmd` reported 0 GPUs.
- **Cause:** a GPU resource without a device file was not counted. On WSL2 the GPU is exposed to containers as `/dev/dxg`; there is no `/dev/nvidia0` (checked with `ls /dev/dxg /dev/nvidia*` inside the container).
- **Fix:** `gres.conf` now uses the device file: `NodeName=c1 Name=gpu File=/dev/dxg`.
- **How I found it:** `scontrol show node c1` (Reason field) and `docker compose logs c1`.

## Node stays `drained` after the config is fixed

- **Symptom:** after correcting `gres.conf` and restarting `c1`, the node showed `IDLE+DRAIN` with the old Reason.
- **Cause:** Slurm drained the node when it first registered with an invalid config; `ReturnToService` does not clear a drain that was set that way.
- **Fix:** `scontrol update nodename=c1 state=resume`. The node then briefly showed `NOT_RESPONDING` and became `idle` within seconds.
