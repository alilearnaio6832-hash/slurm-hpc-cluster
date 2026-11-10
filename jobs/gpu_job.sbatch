#!/bin/bash
#SBATCH --job-name=gpu-smi
#SBATCH --partition=gpu
#SBATCH --gres=gpu:1
#SBATCH --ntasks=1
#SBATCH --time=00:02:00
#SBATCH --output=/shared/%x-%j.out

hostname
echo "CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-unset}"
srun nvidia-smi -L
