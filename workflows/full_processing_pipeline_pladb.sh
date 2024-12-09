#!/usr/bin/bash

##############################
# Full Processing Pipeline CRG Adel Manu Lab for Pladienolide B dataset
# This script processes the Pladienolide B dataset (unpublished) by performing the following steps:
# 1. Concatenate reads
# 2. Trim reads
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
# First job - concatenate reads
echo "Submitting first job: Concatenate reads..."
jid1=$(sbatch $PWD/scripts/bash/pladb_study/processing1_cat_reads_pladb.sh | tr -cd '[:digit:].')
echo "...first job ID is $jid1"

# Third job - align reads (dependent on second job)
echo "Submitting third job: Align reads..."
jid2=$(sbatch --dependency=afterok:$jid1 $PWD/scripts/bash/pladb_study/vast_align_pladb.sh $VASTDB_PATH | tr -cd '[:digit:].')
echo "...third job ID is $jid2"

# Fourth job - generate multiQC report (dependent on third job)
echo "Submitting fourth job: Generate multiQC report..."
jid3=$(sbatch --dependency=afterok:$jid1 $PWD/scripts/bash/pladb_study/multiqc_pladb.sh | tr -cd '[:digit:].')
echo "...fourth job ID is $jid3"

# Fifth job - run vast combine (dependent on third job)
echo "Submitting fifth job: Run vast combine..."
jid4=$(sbatch --dependency=afterok:$jid2 $PWD/scripts/bash/pladb_study/vast_combine_pladb.sh $VASTDB_PATH | tr -cd '[:digit:].')
echo "...fifth job ID is $jid4"

echo "All jobs submitted!"