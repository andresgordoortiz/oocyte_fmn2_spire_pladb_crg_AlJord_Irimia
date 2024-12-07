#!/bin/bash


##################
# slurm settings #
##################

# where to put stdout / stderr
#SBATCH --output=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.out
#SBATCH --error=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.err

# time limit in minutes
#SBATCH --time=30

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
# Store current working directory
current_dir=$PWD
cd $PWD/data/processed/pladienolideb/vast_out/to_combine

# Initialize conda
source ~/miniconda3/etc/profile.d/conda.sh
conda activate vasttools

/users/mirimia/projects/vast-tools/vast-tools combine \
    -sp mm10 \
    -o $current_dir/data/processed/pladienolideb/vast_out
conda deactivate

cd $current_dir
mv $PWD/data/processed/pladienolideb/vast_out/INCLUSION_LEVELS_FULL-mm10-6.tab $PWD/data/processed/pladienolideb/vast_out/pladienolideb_INCLUSION_LEVELS_FULL-mm10.tab

###############
# end message #
###############
end_epoch=`date +%s`
echo [$(date +"%Y-%m-%d %H:%M:%S")] finished on $(hostname) after $((end_epoch-start_epoch)) seconds
