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
#SBATCH --mem=500

# job name
#SBATCH --job-name vast-compare

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
group_a="2022-038_S10_L001_R1_001_merged_trimmed,2022-039_S11_L001_R1_001_merged_trimmed,2022-040_S12_L001_R1_001_merged_trimmed"
group_b="2022-044_S16_L001_R1_001_merged_trimmed,2022-045_S17_L001_R1_001_merged_trimmed,2022-046_S18_L001_R1_001_merged_trimmed"
name_a="Control"
name_b="PladB_treatment_10mM"

singularity exec --bind $PWD/data/processed/pladienolideb/vast_out --bind /users/mirimia/projects/vast-tools/VASTDB/:/VASTDB docker://vastgroup/vast-tools:latest \
    vast-tools compare $PWD/data/processed/pladienolideb/vast_out/INCLUSION_LEVELS_FULL-mm10-9.tab \
    -a $group_a \
    -b $group_b \
    --min_dPSI 5 \
    --min_range 5 \
    --GO --print_dPSI --print_sets \
    -name_A $name_a  -name_B $name_b \
    -sp mm10 > $PWD/data/processed/pladienolideb/vast_out/summary_stats.txt


###############
# end message #
###############
end_epoch=`date +%s`
echo [$(date +"%Y-%m-%d %H:%M:%S")] finished on $(hostname) after $((end_epoch-start_epoch)) seconds
