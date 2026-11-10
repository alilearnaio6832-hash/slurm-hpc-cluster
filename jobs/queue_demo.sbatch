#!/bin/bash
#SBATCH --job-name=queue-demo
#SBATCH --partition=cpu
#SBATCH --array=1-8
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --time=00:02:00
#SBATCH --output=/shared/%x-%A_%a.out

# 8 one-core tasks on a 4-core cluster: the first 4 run, the rest wait in the
# queue (watch with `squeue`). Good for demonstrating scheduling behaviour.
srun python3 /jobs/burn.py 20
