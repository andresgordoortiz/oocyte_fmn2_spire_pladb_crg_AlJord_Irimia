#!/bin/bash

##################
# slurm settings #
##################

# where to put stdout / stderr
#SBATCH --output=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.out
#SBATCH --error=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.err

# time limit in minutes
#SBATCH --time=60

# queue
#SBATCH --qos=vshort

# memory (MB)
#SBATCH --mem=10G
#SBATCH --cpus-per-task=8

# job name
#SBATCH --job-name=trim_fastqc

# Array job - process 15 pairs, max 5 concurrent jobs
#SBATCH --array=0-14

#################
# start message #
#################
start_epoch=`date +%s`
echo [$(date +"%Y-%m-%d %H:%M:%S")] starting on $(hostname) - task ID: $SLURM_ARRAY_TASK_ID

##################################
# make bash behave more robustly #
##################################
set -e
set -u
set -o pipefail

######################
# create directories #
######################
mkdir -p $PWD/data/processed/new_data/trimmed
mkdir -p $PWD/data/processed/new_data/fastqc

#############################
# get files based on array ID #
#############################
# Store the original working directory before changing to raw_dir
original_dir="$PWD"

# Change to raw directory
raw_dir="$PWD/data/raw/new_data"
cd $raw_dir

# Get a list of all "-a.fastq.gz" files
mapfile -t files_a < <(ls *-a.fastq.gz)

# Exit if array index is out of bounds
if [ $SLURM_ARRAY_TASK_ID -ge ${#files_a[@]} ]; then
    echo "Error: SLURM_ARRAY_TASK_ID ($SLURM_ARRAY_TASK_ID) exceeds number of files (${#files_a[@]})"
    exit 1
fi

# Get file corresponding to this array task
file_a=${files_a[$SLURM_ARRAY_TASK_ID]}

# Get matching file_b
base_name=${file_a%-a.fastq.gz}
file_b="${base_name}-b.fastq.gz"

# Check if matching file exists
if [ -f "$file_b" ]; then
    echo "Processing paired files: $file_a and $file_b"

    # Run trim_galore in paired-end mode using absolute paths
    echo "Trimming paired files..."
    singularity exec --bind "$original_dir/data/raw/new_data:/data/raw/new_data" \
        --bind "$original_dir/data/processed/new_data:/data/processed/new_data" \
        docker://quay.io/biocontainers/trim-galore:0.6.9--hdfd78af_0 \
        trim_galore --paired "/data/raw/new_data/$file_a" "/data/raw/new_data/$file_b" \
        --fastqc -j 8 -o /data/processed/new_data/trimmed -q 20 \
        --fastqc_args "-t 8 --outdir /data/processed/new_data/fastqc"

else
    echo "Error: Found $file_a but no matching $file_b"
    exit 1
fi

###############
# end message #
###############
end_epoch=`date +%s`
echo [$(date +"%Y-%m-%d %H:%M:%S")] finished on $(hostname) after $((end_epoch-start_epoch)) seconds - task ID: $SLURM_ARRAY_TASK_ID