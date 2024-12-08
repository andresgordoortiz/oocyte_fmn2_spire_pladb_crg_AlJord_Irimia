#!/bin/bash


##################
# slurm settings #
##################

# where to put stdout / stderr
#SBATCH --output=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.out
#SBATCH --error=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.err

# time limit in minutes
#SBATCH --time=1

# queue
#SBATCH --qos=vshort

# memory (MB)
#SBATCH --mem=200

# job name
#SBATCH --job-name multiqc


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
# run multiqc  #
################
singularity exec --bind $PWD/data/processed/pladb/fastqc docker://multiqc/multiqc:latest multiqc .
mv $PWD/data/processed/pladb/fastqc/multiqc_* $PWD/data/processed/pladb
###############
# end message #
###############
end_epoch=`date +%s`
echo [$(date +"%Y-%m-%d %H:%M:%S")] finished on $(hostname) after $((end_epoch-start_epoch)) seconds