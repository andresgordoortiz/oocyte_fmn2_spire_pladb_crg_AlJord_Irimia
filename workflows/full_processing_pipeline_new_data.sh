#!/usr/bin/bash

##############################
# Full Processing Pipeline CRG Adel Manu Lab
# This script processes the new splicing data by performing the following steps:
# 1. Align reads
# 2. Generate a multiQC report
# 3. Run vast combine
##############################

# SLURM output and error files: (Change accordingly if you want to save them in a different directory)
#SBATCH --output=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.out
#SBATCH --error=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.err


if [ -z "$1" ]; then
    echo "Error: No VASTDB_PATH provided."
    echo "Usage: $0 /path/to/vastdb"
    exit 1
fi

VASTDB_PATH=$1

echo "Submitting first job: cat technical replicates reads..."
jid1=$(sbatch $PWD/scripts/bash/new_data/processing_cat_reads.sh | tr -cd '[:digit:].')
echo "...first job ID is $jid1"

echo "Submitting second job: Trim reads..."
jid2=$(sbatch --dependency=afterok:$jid1 $PWD/scripts/bash/new_data/fastqc_multiqc_new_data.sh | tr -cd '[:digit:].')
echo "...second job ID is $jid2"

echo "Submitting third job: Align reads..."
jid3=$(sbatch --dependency=afterok:$jid2 $PWD/scripts/bash/new_data/vast_align_new_data.sh $VASTDB_PATH | tr -cd '[:digit:].')
echo "...third job ID is $jid3"

echo "Submitting fourth job: Run vast combine..."
jid4=$(sbatch --dependency=afterok:$jid3 $PWD/scripts/bash/new_data/vast_combine_new_data.sh $VASTDB_PATH | tr -cd '[:digit:].')
echo "...fifth job ID is $jid4"

echo "Submitting fifth job: Multiqc..."
jid5=$(sbatch --dependency=afterok:$jid2 $PWD/scripts/bash/new_data/multiqc.sh | tr -cd '[:digit:].')
echo "...second job ID is $jid5"

echo "All jobs submitted!"