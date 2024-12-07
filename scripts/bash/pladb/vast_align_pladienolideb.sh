#!/bin/bash


##################
# slurm settings #
##################

# where to put stdout / stderr
#SBATCH --output=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.out
#SBATCH --error=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.err

# time limit in minutes
#SBATCH --time=180

# queue
#SBATCH --qos=shorter

# memory (MB)
#SBATCH --mem=10G
#SBATCH --cpus-per-task=8

# job name
#SBATCH --job-name vast-align
# job array directive
#SBATCH --array=0-17

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

# Define file list and select the file for the current array job
files=($PWD/data/raw/pladienolideb/*.fastq.gz)
file1=${files[$SLURM_ARRAY_TASK_ID]}

basename=$(basename "$file1" .fastq.gz)
mkdir -p $PWD/data/processed/pladienolideb/vast_out

# Initialize conda
source ~/miniconda3/etc/profile.d/conda.sh
conda activate vasttools
/users/mirimia/projects/vast-tools/vast-tools align \
    "$file1" \
    -sp mm10 \
    -o $PWD/data/processed/pladienolideb/vast_out \
    --IR_version 2 \
    -c 8 \
    -n "$basename"

conda deactivate

###############
# end message #
###############
end_epoch=`date +%s`
echo [$(date +"%Y-%m-%d %H:%M:%S")] finished on $(hostname) after $((end_epoch-start_epoch)) seconds
