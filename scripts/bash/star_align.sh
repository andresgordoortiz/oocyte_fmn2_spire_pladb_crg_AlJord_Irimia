#!/bin/bash


##################
# slurm settings #
##################

# where to put stdout / stderr
#SBATCH --output=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.out
#SBATCH --error=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.err

# time limit in minutes
#SBATCH --time=120

# queue
#SBATCH --qos=short

# memory (MB)
#SBATCH --mem=40G
#SBATCH --cpus-per-task=8

# job name
#SBATCH --job-name star-align


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


mkdir -p star_align_out
# Initialize conda
singularity exec docker://mgibio/star:latest STAR --runThreadN 8 \
     --genomeDir $PWD/ensemblgenome \
     --readFilesIn $PWD/data/processed/pladienolideb/2022_038_S10_L001_R1_001_merged_trimmed.fq.gz \
     --readFilesCommand zcat \
     --outFileNamePrefix $PWD/star_align_out \
     --outSAMtype BAM SortedByCoordinate


###############
# end message #
###############
end_epoch=`date +%s`
echo [$(date +"%Y-%m-%d %H:%M:%S")] finished on $(hostname) after $((end_epoch-start_epoch)) seconds
