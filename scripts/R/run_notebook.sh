#!/usr/bin/bash


##################
# slurm settings #
##################

# SLURM output and error files
#SBATCH --output=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.out
#SBATCH --error=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.err

# time limit in minutes
#SBATCH --time=90

# queue
#SBATCH --qos=short

# memory (MB)
#SBATCH --mem=15G
#SBATCH --cpus-per-task=2

# job name
#SBATCH --job-name run_RMarkdown

#################
# start message #
#################
start_epoch=`date +%s`
echo [$(date +"%Y-%m-%d %H:%M:%S")] starting on $(hostname)

##################################
# make bash behave more robustly #
##################################
set -e
set -u
set -o pipefail

# Run RMarkdown
singularity run --bind "$(pwd)/notebooks:/shared" \
  docker://andresgordoortiz/splicing_analysis_r_crg:v1.1 \
  /shared/oocyte_transcript_analysis.rmd
###############
# end message #
###############
end_epoch=`date +%s`
echo [$(date +"%Y-%m-%d %H:%M:%S")] finished on $(hostname) after $((end_epoch-start_epoch)) seconds