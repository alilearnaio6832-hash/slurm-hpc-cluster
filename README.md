# HPC Cluster with Slurm (containerized lab)

A small Slurm cluster (1 controller + 2 compute nodes) that runs on a single machine with Docker Compose.
Built as a hands-on project for **Linux administration, networking and workload scheduling**, and as the base
layer for a GPU monitoring and benchmarking portfolio.

> **Scope, stated honestly:** this is a *simulated* multi-node cluster. All "nodes" are containers on one host,
> so it demonstrates Slurm configuration and scheduling behaviour, not real multi-machine networking or
> multi-node GPU hardware.

## Architecture

```mermaid
flowchart TD
    U["Users alice and bob"] --> C["slurmctld controller"]
    C --> N1["c1 slurmd"]
    C --> N2["c2 slurmd"]
    C --- S["shared volume"]
    N1 --- S
    N2 --- S
    M["MUNGE key"] -.-> C
    M -.-> N1
    M -.-> N2
```

| Component | Role |
|---|---|
| `slurmctld` | Controller: accepts jobs, schedules them, keeps cluster state |
| `c1`, `c2` | Compute nodes running `slurmd` (2 CPUs / 1 GB each in config) |
| MUNGE | Authentication between all Slurm daemons |
| `/shared` volume | Stand-in for NFS: job output visible from every node |
| `alice`, `bob` | Sample users with identical UIDs on every node |

## Quick start

Requirements: Docker with the Compose plugin (Docker Desktop with WSL2 works).

```bash
make up          # build the image and start the cluster
make status      # sinfo: both nodes should be "idle"
make test        # runs a 2-node job as user alice
make queue       # submits 8 jobs to a 4-core cluster, shows the queue
make shell       # shell as alice inside the controller
make clean       # stop and delete everything, including the volume
```

If a node shows `inval` or `drain`, your Docker host has fewer resources than `configs/slurm.conf` claims.
Run `docker compose exec c1 slurmd -C` and adjust the `NodeName=` line.

## Monitoring

`make up` also starts a small monitoring stack:

| URL | What |
|---|---|
| http://localhost:23000 | Grafana (login `admin` / `admin`, local only), dashboard **Slurm GPU Cluster** |
| http://localhost:29090 | Prometheus |
| http://localhost:19500/metrics | Slurm exporter |

The Slurm exporter (`monitoring/slurm_exporter.py`, Python standard library only) reads `squeue` and `scontrol` and exposes job counts by state, CPUs, memory and GPUs allocated per node, and node health.

The GPU hardware panels (utilization, memory, power, temperature) use the `gpu-exporter` of a separate GPU monitoring project. If its Docker network `deploy_default` exists, `make up` connects Prometheus to it automatically (`docker-compose.project1.yml`). Without that project the Slurm panels are expected to work and the GPU hardware panels will have no data (this case is not tested). Start the cluster with `make up`, not with `docker compose up`, so the optional file is picked up.

## Repository layout

```
.
├── docker-compose.yml     # controller + 2 compute nodes + exporter, Prometheus, Grafana
├── docker-compose.project1.yml  # optional: connects Prometheus to the GPU monitoring project
├── monitoring/            # Slurm exporter, Prometheus config, Grafana provisioning + dashboard
├── docker/                # Dockerfile and entrypoint (MUNGE + slurmctld/slurmd)
├── configs/slurm.conf     # cluster, node and partition definition
├── jobs/                  # sample batch scripts
├── scripts/smoke_test.sh  # end-to-end check
├── docs/troubleshooting.md
└── results/               # screenshots and measurements (fill in as you go)
```

## Roadmap

- [x] **Phase 1:** controller + 2 compute nodes, MUNGE auth, CPU partition, sample jobs
- [x] **Phase 2:** GPU node: `c1` has `Gres=gpu:1` (real RTX 5060 Ti via `/dev/dxg`), `gpu` partition, `--gres=gpu:1` jobs
- [ ] **Phase 3:** accounting (`slurmdbd` + MariaDB), per-user limits, fair-share
- [x] **Phase 4:** Slurm exporter + Prometheus + Grafana dashboard (queue, CPU/GPU allocation, GPU hardware metrics)
- [ ] **Phase 5 (optional):** same cluster on 2 to 3 real VMs with NFS, for true multi-host networking

## Results

**CPU scheduling:** 8 one-core jobs on a 4-core cluster. Before setting `DefMemPerCPU=250` only 2 jobs ran at once; after, 4 ran at once (2 per node) and the rest queued. See `results/03a-queue-before-fix.txt` and `results/03b-queue-after-fix.txt`.

**GPU scheduling:** `c1` exposes the host's RTX 5060 Ti to Slurm as `gres/gpu:1`. A 3-task array of `--gres=gpu:1` jobs ran one task at a time on `c1` while the other two waited with reason `(Resources)`. Slurm set `CUDA_VISIBLE_DEVICES=0` for the running job. See `results/04-gpu-queue.txt` and `results/07-gpu-job-output.txt`.

**Monitoring:** the dashboard below was captured while 3 jobs were running and 5 were waiting. Slurm reports the GPU as 100% allocated while the real GPU utilization is about 0%, because the demo jobs only sleep; CPU allocation is 75%, so the queue is waiting on the single GPU, not on CPUs.

![Grafana dashboard](results/08-grafana-dashboard.png)

## Limitations

- Simulated cluster: all nodes are containers on one machine.
- The demo jobs do not use the GPU, so real GPU utilization stays near zero in the dashboard. Real GPU workloads come in a separate benchmarking project.
- One physical GPU, declared on `c1` only. Multi-GPU and multi-node GPU scheduling are not tested.
- WSL2 exposes the GPU as `/dev/dxg`, so `gres.conf` points at that file. Slurm runs with `task/none` (no cgroup device constraint), so GPU access is not enforced per job: the `c1` container itself has the GPU.

## Problems and fixes

See [docs/troubleshooting.md](docs/troubleshooting.md). Keep this updated while building; it is the most
valuable part of the repository for a reader.

## Security note

The MUNGE key is generated at image build time for lab use only and is not stored in the repository. Grafana uses the default `admin` / `admin` login and all monitoring ports are bound to `127.0.0.1` only; change the password before exposing anything.
