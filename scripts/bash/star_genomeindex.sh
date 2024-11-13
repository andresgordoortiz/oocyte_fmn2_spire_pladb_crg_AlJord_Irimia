#!/bin/bash


##################
# slurm settings #
##################

# where to put stdout / stderr
#SBATCH --output=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.out
#SBATCH --error=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.err

# time limit in minutes
#SBATCH --time=40

# queue
#SBATCH --qos=vshort

# memory (MB)
#SBATCH --mem=60G
#SBATCH --cpus-per-task=8

# job name
#SBATCH --job-name star-genomeindex_mouse


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

mkdir -p $PWD/star_index/Mus_musculus

# Initialize conda
singularity exec docker://mgibio/star:latest STAR --runMode genomeGenerate \
    --genomeDir $PWD/star_index/Mus_musculus \
    --genomeFastaFiles $PWD/assemblygenomes_ensembl/Mus_musculus.GRCm39.dna.primary_assembly.fa \
    --sjdbGTFfile $PWD/assemblygenomes_ensembl/Mus_musculus.GRCm39.113.gtf \
    --runThreadN 8


###############
# end message #
###############
end_epoch=`date +%s`
echo [$(date +"%Y-%m-%d %H:%M:%S")] finished on $(hostname) after $((end_epoch-start_epoch)) seconds
