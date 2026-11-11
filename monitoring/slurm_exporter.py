#!/usr/bin/env python3
"""Minimal Prometheus exporter for Slurm (stdlib only).

Reads cluster state with squeue and scontrol and serves it on :9500/metrics.
"""
import re
import subprocess
from collections import Counter
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = 9500


def run(cmd):
    out = subprocess.run(cmd, capture_output=True, text=True, timeout=10)
    if out.returncode != 0:
        raise RuntimeError(out.stderr.strip() or "command failed: " + " ".join(cmd))
    return out.stdout


def gpu_count(text):
    """'gpu:1' or 'gpu:rtx:1' or 'gres:gpu:1' -> 1 (0 when no gpu)."""
    m = re.search(r"gpu(?::[A-Za-z0-9_]+)?:(\d+)", text or "")
    return int(m.group(1)) if m else 0


def collect():
    lines = []

    def add(name, help_text, kind="gauge"):
        lines.append("# HELP %s %s" % (name, help_text))
        lines.append("# TYPE %s %s" % (name, kind))

    # Jobs by state (-r: one row per array task)
    states = Counter(s.strip() for s in run(["squeue", "-h", "-r", "-o", "%T"]).splitlines() if s.strip())
    add("slurm_jobs", "Jobs in the queue by state")
    for st in ("PENDING", "RUNNING", "COMPLETING"):
        states.setdefault(st, 0)
    for st, n in sorted(states.items()):
        lines.append('slurm_jobs{state="%s"} %d' % (st.lower(), n))

    # GPUs held by running jobs, per node (squeue %b = TRES per node, e.g. gres:gpu:1)
    gpu_used = Counter()
    for row in run(["squeue", "-h", "-r", "-t", "R", "-o", "%N|%b"]).splitlines():
        node, _, tres = row.partition("|")
        if node.strip():
            gpu_used[node.strip()] += gpu_count(tres)

    # Nodes
    nodes = []
    for row in run(["scontrol", "show", "node", "-o"]).splitlines():
        f = dict(re.findall(r"(\w+)=(\S*)", row))
        if "NodeName" in f:
            nodes.append(f)

    add("slurm_node_cpus_total", "Configured CPUs per node")
    add("slurm_node_cpus_alloc", "Allocated CPUs per node")
    add("slurm_node_memory_alloc_mb", "Allocated memory per node in MB")
    add("slurm_node_gpus_total", "Configured GPUs per node")
    add("slurm_node_gpus_alloc", "GPUs held by running jobs per node")
    add("slurm_node_up", "1 when the node is not down, drained, invalid or unresponsive")
    for f in nodes:
        n = f["NodeName"]
        lab = 'node="%s"' % n
        state = f.get("State", "UNKNOWN").upper()
        up = 0 if re.search(r"DOWN|DRAIN|INVAL|NOT_RESPONDING|FAIL", state) else 1
        lines.append("slurm_node_cpus_total{%s} %s" % (lab, f.get("CPUTot", 0)))
        lines.append("slurm_node_cpus_alloc{%s} %s" % (lab, f.get("CPUAlloc", 0)))
        lines.append("slurm_node_memory_alloc_mb{%s} %s" % (lab, f.get("AllocMem", 0)))
        lines.append("slurm_node_gpus_total{%s} %d" % (lab, gpu_count(f.get("Gres"))))
        lines.append("slurm_node_gpus_alloc{%s} %d" % (lab, gpu_used.get(n, 0)))
        lines.append("slurm_node_up{%s,state=\"%s\"} %d" % (lab, state.lower(), up))

    lines.append("# HELP slurm_exporter_up 1 when the last scrape of Slurm succeeded")
    lines.append("# TYPE slurm_exporter_up gauge")
    lines.append("slurm_exporter_up 1")
    return "\n".join(lines) + "\n"


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != "/metrics":
            self.send_response(404)
            self.end_headers()
            return
        try:
            body = collect()
        except Exception as exc:  # report failure as a metric instead of a 500
            body = "# slurm query failed: %s\nslurm_exporter_up 0\n" % str(exc).replace("\n", " ")
        data = body.encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain; version=0.0.4")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, *args):
        pass


if __name__ == "__main__":
    HTTPServer(("0.0.0.0", PORT), Handler).serve_forever()
