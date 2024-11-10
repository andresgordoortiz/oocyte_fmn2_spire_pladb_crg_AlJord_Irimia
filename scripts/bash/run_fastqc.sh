#!/bin/bash

##################
# slurm settings #
##################

# where to put stdout / stderr
#SBATCH --output=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A.out
#SBATCH --error=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A.err

# time limit in minutes
#SBATCH --time=60

# queue
#SBATCH --qos=short

# memory (MB)
#SBATCH --mem=10G

# job name
#SBATCH --job-name fastqc_multiqc

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


################
# run fastqc   #
################
cd ~/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/downloads
singularity exec docker://biocontainers/fastqc:v0.11.9_cv8 fastqc *.fastq.gz

################
# run multiqc  #
################
singularity exec docker://biocontainers/multiqc:latest multiqc .

###############
# end message #
###############
end_epoch=`date +%s`
echo [$(date +"%Y-%m-%d %H:%M:%S")] finished on $(hostname) after $((end_epoch-start_epoch)) seconds