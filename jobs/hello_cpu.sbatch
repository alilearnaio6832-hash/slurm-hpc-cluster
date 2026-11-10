#!/bin/bash
#SBATCH --job-name=hello-cpu
#SBATCH --partition=cpu
#SBATCH --nodes=2
#SBATCH --ntasks=2
#SBATCH --time=00:02:00
#SBATCH --output=/shared/%x-%j.out

# One task per node: the output shows both compute nodes answering.
srun hostname
