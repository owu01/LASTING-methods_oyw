#!/bin/bash
# Slurm batch script: SENSITIVITY ANALYSIS (negative PIFs kept), TWO diet patterns
# (US20 and US25) run at the same time, 100 simulations. Counterfactuals that are
# less favourable than current intake count as added disease instead of zero benefit.
# Results go to the LASTING project space:
#   /cluster/tufts/lasting/shared/LASTING-methods_oyw_cra/outputs/model_negPIF/output_<date>/CRA/US20/ and /US25/
# Submit from the folder this file is in with:   sbatch run_cra_US20_US25_100sims_negPIF.sh

#SBATCH --job-name=negPIF_US20_US25
#SBATCH --partition=batch            # Tufts general-purpose partition
#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=3            # one core per diet (2) + 1 spare
#SBATCH --mem=32G                    # one diet at 100 simulations used about 7 GB; two run together
#SBATCH --time=1-00:00:00            # time limit (days-hours:min:sec)
#SBATCH --output=negPIF_US20_US25_%j.out       # %j = job ID
#SBATCH --error=negPIF_US20_US25_%j.err
#SBATCH --mail-type=BEGIN,END,FAIL
#SBATCH --mail-user=olivia.wu@tufts.edu

# Run settings, read by 08-run-models_CRA_only_HUSS_cluster.R
export ALLOW_NEGATIVE_PIF=TRUE        # sensitivity analysis: keep negative PIFs
export NSIM1=100                     # number of simulations
export DIETS=US20,US25                 # diet patterns for this job (run in parallel)

# Where results are written: the LASTING project space (shared with the whole team)
export OUTPUT_BASE=/cluster/tufts/lasting/shared/LASTING-methods_oyw_cra/outputs/model_negPIF   # separate from main results
mkdir -p "$OUTPUT_BASE"

# Safety check: this space is shared and filled up before. Do not start unless
# there is at least 6 GB free (each diet at 100 simulations uses about 1.3 GB).
MIN_FREE_GB=6
FREE_GB=$(df -BG --output=avail /cluster/tufts/lasting | tail -1 | tr -dc '0-9')
echo "Free space in /cluster/tufts/lasting: ${FREE_GB} GB"
if [ "$FREE_GB" -lt "$MIN_FREE_GB" ]; then
  echo "Only ${FREE_GB} GB free in /cluster/tufts/lasting (need ${MIN_FREE_GB} GB). Not starting." >&2
  exit 1
fi

# Load R 4.5.1 (it sits in the deprecated module tree, which must be loaded first)
module purge
module load modtree/deprecated
module load R/4.5.1

# Stop straight away if R did not load
if ! command -v Rscript > /dev/null; then
  echo "Rscript not found: R module did not load" >&2
  exit 1
fi
Rscript --version

# Project folder (not code/), so the relative paths in the R script work
cd /cluster/tufts/lasting/shared/LASTING-methods_oyw_cra || { echo "Project folder not found" >&2; exit 1; }

if [ ! -f code/08-run-models_CRA_only_HUSS_cluster.R ]; then
  echo "R script not found: code/08-run-models_CRA_only_HUSS_cluster.R" >&2
  exit 1
fi

# Record when and where the job ran, and free space in your home directory
echo "Job $SLURM_JOB_ID started on $(hostname) at $(date)"
echo "Diet: $DIETS   Simulations: $NSIM1"
echo "Free space before the run: $(df -h --output=avail /cluster/tufts/lasting | tail -1)"

# Run the model
Rscript code/08-run-models_CRA_only_HUSS_cluster.R

echo "Free space after the run: $(df -h --output=avail /cluster/tufts/lasting | tail -1)"
for d in ${DIETS//,/ }; do
  echo "Size of $d results: $(du -sh "$OUTPUT_BASE"/output_*/CRA/$d 2>/dev/null | tail -1 | cut -f1)"
done
echo "Job finished at $(date)"
