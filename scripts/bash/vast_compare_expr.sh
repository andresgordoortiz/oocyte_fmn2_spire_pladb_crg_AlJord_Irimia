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

# job name
#SBATCH --job-name vast-compare_expr

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
group_a="SRR6026682_SRR6026683_SRR6026684_merged_trimmed,SRR6026685_SRR6026686_SRR6026687_merged_trimmed"
group_b="SRR6026688_SRR6026689_SRR6026690_merged_trimmed,SRR6026691_SRR6026692_SRR6026693_merged_trimmed"
name_a="Control"
name_b="Fmn2DKO"

singularity exec --bind $PWD/data/processed/fmn2dko/vast_out --bind /users/mirimia/projects/vast-tools/VASTDB/:/VASTDB docker://andresgordoortiz/vast-tools:latest \
    vast-tools compare_expr $PWD/data/processed/fmn2dko/vast_out/cRPKM-mm10-4.tab \
    -a $group_a \
    -b $group_b \
    --min_fold_av 2 \
    --min_cRPKM 2 \
    --GO \
    --norm  > summary_stats_expression.txt


###############
# end message #
###############
end_epoch=`date +%s`
echo [$(date +"%Y-%m-%d %H:%M:%S")] finished on $(hostname) after $((end_epoch-start_epoch)) seconds
