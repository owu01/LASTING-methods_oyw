#!/bin/bash
# Slurm batch script: runs the NCI/SIMPLE standard-deviation SAS program on the Tufts HPC.
# Submit from the folder this file is in with:   sbatch Run_SDs_cluster_HUSS.sh

#SBATCH --job-name=nci_sd_huss
#SBATCH --partition=batch            # Tufts general-purpose partition
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=4
#SBATCH --mem=32G                    # memory for the job
#SBATCH --time=3-00:00:00            # time limit (days-hours:min:sec); BRR runs are slow
#SBATCH --output=nci_sd_huss_%j.out  # %j = job ID
#SBATCH --error=nci_sd_huss_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=olivia.wu@tufts.edu

# Load SAS (check the exact module name with:  module avail sas)
module purge
module load sas

# Folder that contains your SAS program
cd /cluster/tufts/lasting/shared/LASTING-methods_oyw/data_inputs/DIET/standard-deviations

# Run SAS in batch mode; the log and listing files are saved next to the program
sas Calculate_SD_nci_method_by_subgroup_HUSS.sas \
    -noterminal \
    -log Calculate_SD_nci_method_by_subgroup_HUSS.log \
    -print Calculate_SD_nci_method_by_subgroup_HUSS.lst
