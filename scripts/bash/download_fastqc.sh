#!/bin/bash

# Run this using the following command:
# sbatch scripts/bash/download_fastqc.sh ~/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/scripts/bash/fmndko_PRJNA406820.sh
##################
# slurm settings #
##################

# where to put stdout / stderr
#SBATCH --output=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.out
#SBATCH --error=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.err

# time limit in minutes
#SBATCH --time=5

# queue
#SBATCH --qos=vshort

# memory (MB)
#SBATCH --mem=4G

# job name
#SBATCH --job-name downloadfasta

# job array directive
#SBATCH --array=0-11

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

###############
# run command #
###############
mkdir -p downloads
cd downloads
sed "$((SLURM_ARRAY_TASK_ID + 1))q;d" "$1" | bash

###############
# end message #
###############
end_epoch=`date +%s`
echo [$(date +"%Y-%m-%d %H:%M:%S")] finished on $(hostname) after $((end_epoch-start_epoch)) seconds

#####################
# submit fastqc job #
#####################
echo [$(date +"%Y-%m-%d %H:%M:%S")] submitting fastqc job
if [ "$SLURM_ARRAY_TASK_ID" -eq "$(($(wc -l < "$1") - 1))" ]; then
  sbatch --dependency=afterok:$SLURM_JOB_ID ~/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/scripts/bash/run_fastqc.sh
fi