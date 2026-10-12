#!/bin/bash
# Slurm ARRAY batch script: runs the NCI/SIMPLE SD program once per diet variable.
# Task N reads in/array/macro_input_taskNN.csv (13 tasks = the 13 variables not yet finished).
# Submit from the standard_deviations folder with:   sbatch Run_SDs_cluster_array_HUSS.sh
# To rerun only some tasks (e.g. 3 and 7):           sbatch --array=3,7 Run_SDs_cluster_array_HUSS.sh

#SBATCH --job-name=nci_sd_array
#SBATCH --partition=batch
#SBATCH --array=1-13                      # one task per remaining diet variable
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=1
#SBATCH --mem=16G                         # per task; the last run peaked at about 5 GB
#SBATCH --time=12:00:00                   # per task; one variable took about 2-2.5 hours
#SBATCH --output=logs/nci_sd_%A_%a.out    # %A = job ID, %a = task number
#SBATCH --error=logs/nci_sd_%A_%a.err
#SBATCH --mail-type=END,FAIL
#SBATCH --mail-user=olivia.wu@tufts.edu

# Load SAS 9.4 (it sits in the deprecated module tree, which must be loaded first)
module purge
module load modtree/deprecated
module load SAS/9.4

# Folder that contains the SAS program
cd /cluster/tufts/lasting/shared/LASTING-methods_oyw/data_inputs/DIET/standard_deviations

# Two-digit task number, used in the log file names
TASK=$(printf "%02d" "$SLURM_ARRAY_TASK_ID")

# Run SAS in batch mode (sas_u8 is the actual SAS program; the "sas" alias does not work in batch scripts)
sas_u8 Calculate_SD_nci_method_array_HUSS.sas \
    -noterminal \
    -log logs/Calculate_SD_nci_method_array_HUSS_task${TASK}.log \
    -print logs/Calculate_SD_nci_method_array_HUSS_task${TASK}.lst
