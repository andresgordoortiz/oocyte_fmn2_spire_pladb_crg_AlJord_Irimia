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
#SBATCH --mem=5G

# job name
#SBATCH --job-name vast-combine


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


singularity exec --bind $PWD/data/processed/fmn2dko/vast_out/to_combine --bind /users/mirimia/projects/vast-tools/VASTDB/:/VASTDB docker://vastgroup/vast-tools:latest \
    vast-tools combine \
    -sp mm10 \
    -o $PWD/data/processed/fmn2dko/vast_out


###############
# end message #
###############
end_epoch=`date +%s`
echo [$(date +"%Y-%m-%d %H:%M:%S")] finished on $(hostname) after $((end_epoch-start_epoch)) seconds
