#!/bin/bash
#SBATCH --job-name=gpu-queue
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --array=1-3
#SBATCH --ntasks=1
#SBATCH --time=00:02:00
#SBATCH --output=/shared/%x-%A_%a.out

echo "task ${SLURM_ARRAY_TASK_ID} on $(hostname) with CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"
srun sleep 20
