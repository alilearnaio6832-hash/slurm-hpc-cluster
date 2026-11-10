FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# One image for every role (controller + compute nodes), so UIDs/GIDs of the
# slurm and munge users are identical on all nodes, as Slurm requires.
RUN apt-get update && apt-get install -y --no-install-recommends \
        slurm-wlm munge python3 iproute2 iputils-ping procps ca-certificates \
    && rm -rf /var/lib/apt/lists/*

# Lab-only MUNGE key, generated at build time and never committed to the repo.
# In a real cluster the key is distributed to every node out-of-band.
RUN dd if=/dev/urandom bs=1 count=1024 of=/etc/munge/munge.key 2>/dev/null \
    && chown munge:munge /etc/munge/munge.key \
    && chmod 400 /etc/munge/munge.key

# Two sample users with fixed UIDs (same on every node).
RUN useradd -m -u 2001 -s /bin/bash alice \
    && useradd -m -u 2002 -s /bin/bash bob

# Stand-in for shared storage (NFS in a real cluster): a volume mounted on all nodes.
RUN mkdir -p /shared && chmod 1777 /shared

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
