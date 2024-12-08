#!/usr/bin/bash

##############################
# Full Processing Pipeline CRG Adel Manu Lab for FMNDKO dataset
# This script processes the Pladienolide B dataset (unpublished) by performing the following steps:
# 1. Download the dataset from ENA
# 2. Concatenate reads
# 3. Align reads
# 4. Generate a multiQC report
# 5. Run vast combine
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

# Downlaoding Dataset from ENA
echo "Submitting first job: Downloading reads from ENA..."
jid1=$(sbatch $PWD/scripts/bash/fmndko_study/downloading_fmndko.sh | tr -cd '[:digit:].')
echo "...first job ID is $jid1"

# Second job - concatenate reads
echo "Submitting second job: Concatenate reads..."
jid2=$(sbatch --dependency=afterok:$jid1 $PWD/scripts/bash/fmndko_study/processing1_cat_reads_fmndko.sh | tr -cd '[:digit:].')
echo "...first job ID is $jid2"

# Third job - fastQC (dependent on second job)
echo "Submitting second job: Trim reads..."
jid3=$(sbatch --dependency=afterok:$jid2 $PWD/scripts/bash/fmndko_study/fastqc_multiqc_fmndko.sh | tr -cd '[:digit:].')
echo "...second job ID is $jid3"

# Fourth job - align reads (dependent on second job)
echo "Submitting third job: Align reads..."
jid4=$(sbatch --dependency=afterok:$jid2 $PWD/scripts/bash/fmndko_study/vast_align_fmndko.sh $VASTDB_PATH | tr -cd '[:digit:].')
echo "...third job ID is $jid4"

# Fifth job - run vast combine (dependent on fourth job)
echo "Submitting fifth job: Run vast combine..."
jid5=$(sbatch --dependency=afterok:$jid4 $PWD/scripts/bash/fmndko_study/vast_combine_fmndko.sh $VASTDB_PATH | tr -cd '[:digit:].')
echo "...fifth job ID is $jid5"

echo "All jobs submitted!"