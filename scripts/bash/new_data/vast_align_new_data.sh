#!/bin/bash


##################
# slurm settings #
##################

# where to put stdout / stderr
#SBATCH --output=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.out
#SBATCH --error=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.err

# time limit in minutes
#SBATCH --time=240
# queue
#SBATCH --qos=short
#SBATCH --requeue

# memory (MB)
#SBATCH --mem=32G
#SBATCH --cpus-per-task=8

# job name
#SBATCH --job-name vast-align
# job array directive
#SBATCH --array=0-14

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

# Define file list and select the pair for the current array job
# Assuming files are named like sample-a.fastq.gz and sample-b.fastq.gz
file_a_list=($PWD/data/raw/new_data/*-a.fastq.gz)
file_a=${file_a_list[$SLURM_ARRAY_TASK_ID]}

# Get the corresponding -b file
file_b="${file_a/-a.fastq.gz/-b.fastq.gz}"

# Extract base name without -a.fastq.gz
basename=$(basename "$file_a" -a.fastq.gz)
mkdir -p $PWD/data/processed/new_data/vast_out

singularity_image="docker://andresgordoortiz/vast-tools:latest"
VASTDB_PATH=$1

# Run vast-tools align using Singularity in paired-end mode
singularity exec --bind $VASTDB_PATH:/usr/local/vast-tools/VASTDB \
    --bind $PWD/data/processed/new_data/vast_out:/vast_out \
    $singularity_image vast-tools align \
    "$file_a" \
    "$file_b" \
    -sp mm10 \
    -o /vast_out \
    --IR_version 2 \
    -c 8 \
    -n "$basename"

###############
# end message #
###############
end_epoch=`date +%s`
echo [$(date +"%Y-%m-%d %H:%M:%S")] finished on $(hostname) after $((end_epoch-start_epoch)) seconds
