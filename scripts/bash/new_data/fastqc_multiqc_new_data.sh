#!/bin/bash

##################
# slurm settings #
##################

# where to put stdout / stderr
#SBATCH --output=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A.out
#SBATCH --error=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A.err

# time limit in minutes - increased for trimming
#SBATCH --time=120

# queue
#SBATCH --qos=short

# memory (MB) - increased for trimming
#SBATCH --mem=16G
#SBATCH --cpus-per-task=8

# job name
#SBATCH --job-name trim_fastqc_multiqc

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

######################
# create directories #
######################
mkdir -p $PWD/data/processed/new_data/trimmed
mkdir -p $PWD/data/processed/new_data/fastqc

#############################
# identify paired-end files #
#############################
echo "Identifying paired-end files..."
raw_dir="$PWD/data/raw/new_data"
cd $raw_dir

# Find all files with "-a.fastq.gz" suffix and their corresponding "-b.fastq.gz" pairs
for file_a in *-a.fastq.gz; do
    # Extract base name without the "-a.fastq.gz" suffix
    base_name=${file_a%-a.fastq.gz}
    file_b="${base_name}-b.fastq.gz"

    # Check if the corresponding "-b" file exists
    if [ -f "$file_b" ]; then
        echo "Found paired files: $file_a and $file_b"

        # Run trim_galore in paired-end mode
        echo "Trimming paired files..."
        singularity exec --bind $PWD/data/raw/new_data:$PWD/data/raw/new_data --bind $PWD/data/processed/new_data:$PWD/data/processed/new_data \
            docker://quay.io/biocontainers/trim-galore:0.6.9--hdfd78af_0 \
            trim_galore --paired "$raw_dir/$file_a" "$raw_dir/$file_b" \
            --fastqc -j 8 -o $PWD/data/processed/new_data/trimmed -q 20 \
            --fastqc_args "-t 8 --outdir $PWD/data/processed/new_data/fastqc"
    else
        echo "Warning: Found $file_a but no matching $file_b"
    fi
done


################
# run multiqc  #
################
echo "Running MultiQC on trimmed data FastQC results..."
singularity exec --bind $PWD/data/processed/new_data:/new_data \
    docker://multiqc/multiqc:latest \
    /bin/bash -c "cd /new_data && multiqc . -n new_data_trimmed_multiqc_report.html"

###############
# end message #
###############
end_epoch=`date +%s`
echo [$(date +"%Y-%m-%d %H:%M:%S")] finished on $(hostname) after $((end_epoch-start_epoch)) seconds