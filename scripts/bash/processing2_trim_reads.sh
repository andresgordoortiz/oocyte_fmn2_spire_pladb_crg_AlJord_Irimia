#!/bin/bash


##################
# slurm settings #
##################

# where to put stdout / stderr
#SBATCH --output=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.out
#SBATCH --error=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.err

# time limit in minutes
#SBATCH --time=10

# queue
#SBATCH --qos=vshort

# memory (MB)
#SBATCH --mem=10G
#SBATCH --cpus-per-task=8

# job name
#SBATCH --job-name trim_reads
# job array directive
#SBATCH --array=0-3
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
files=($PWD/downloads/*.fastq.gz)
file=${files[$SLURM_ARRAY_TASK_ID]}

# Run the trimming command for the selected file
singularity exec --bind $PWD/downloads \
    docker://dceoy/trim_galore:latest \
    trim_galore "$file" \
    --fastqc -j 8 -o $PWD/downloads/trimmed -q 10 \
    --fastqc_args "-t 8 --outdir $PWD/downloads/trimmed"



###############
# end message #
###############
end_epoch=`date +%s`
echo [$(date +"%Y-%m-%d %H:%M:%S")] finished on $(hostname) after $((end_epoch-start_epoch)) seconds

