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
#SBATCH --mem=4G
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

# Loop through each fastq.gz file and run the singularity command
for file in $PWD/downloads/*.fastq.gz; do
    singularity exec --bind $PWD/downloads \
        docker://genomicpariscentre/trimgalore:0.6.10 \
        trim_galore "$file" \
        --fastqc -j 8 -o $PWD/downloads/trimmed \
        --fastqc_args "-t 8 --outdir $PWD/downloads/trimmed"
done

################
# run multiqc  #
################
module load MultiQC/1.22.3-foss-2023b
cd $PWD/downloads
multiqc .

###############
# end message #
###############
end_epoch=`date +%s`
echo [$(date +"%Y-%m-%d %H:%M:%S")] finished on $(hostname) after $((end_epoch-start_epoch)) seconds

