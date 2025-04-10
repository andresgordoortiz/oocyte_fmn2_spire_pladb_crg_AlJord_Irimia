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


# Third job - trim & fastQC
echo "Submitting second job: Trim reads..."
jid1=$(sbatch $PWD/scripts/bash/new_data/fastqc_multiqc_new_data.sh | tr -cd '[:digit:].')
echo "...second job ID is $jid1"

# Fourth job - align reads (dependent on second job)
echo "Submitting third job: Align reads..."
jid2=$(sbatch --dependency=afterok:$jid1 $PWD/scripts/bash/new_data/vast_align_new_data.sh $VASTDB_PATH | tr -cd '[:digit:].')
echo "...third job ID is $jid2"

# Fifth job - run vast combine (dependent on fourth job)
echo "Submitting fifth job: Run vast combine..."
jid3=$(sbatch --dependency=afterok:$jid2 $PWD/scripts/bash/new_data/vast_combine_new_data.sh $VASTDB_PATH | tr -cd '[:digit:].')
echo "...fifth job ID is $jid3"

# Third job - Multiqc
echo "Submitting second job: Multiqc..."
jid4=$(sbatch --dependency=afterok:$jid1 $PWD/scripts/bash/new_data/multiqc.sh | tr -cd '[:digit:].')
echo "...second job ID is $jid4"

echo "All jobs submitted!"