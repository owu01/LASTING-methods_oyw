#!/bin/bash
# Slurm batch script: runs the CRA-only model (HUSS 2020/2025 with LASTING inputs) on the Tufts HPC.
# TEST RUN: 10 simulations, 16 GB memory, 12-hour limit.
# Submit from the folder this file is in with:   sbatch run_cra_test.sh

#SBATCH --job-name=huss_cra_test
#SBATCH --partition=batch            # Tufts general-purpose partition
#SBATCH --nodes=1
#SBATCH --ntasks=1                   # one task (R itself starts the parallel workers)
#SBATCH --cpus-per-task=4            # 3 diets in parallel + 1 spare
#SBATCH --mem=16G                    # memory for the job
#SBATCH --time=0-12:00:00            # time limit (days-hours:min:sec); must not exceed the partition limit
#SBATCH --output=huss_cra_test_%j.out
#SBATCH --error=huss_cra_test_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=olivia.wu@tufts.edu

# Number of simulations, read by 08-run-models_CRA_only_HUSS_cluster.R
export NSIM1=10

# Load R (same version the packages were installed with)
module purge
module load R/4.5.1

# Project folder, so the relative paths in the R script work
cd /cluster/tufts/lasting/shared/LASTING-methods_oyw_cra

# Record when and where the job ran
echo "Job $SLURM_JOB_ID started on $(hostname) at $(date)"
echo "CPUs allocated: $SLURM_CPUS_PER_TASK   Simulations: $NSIM1"

# Run the model
Rscript 08-run-models_CRA_only_HUSS_cluster.R

echo "Job finished at $(date)"
