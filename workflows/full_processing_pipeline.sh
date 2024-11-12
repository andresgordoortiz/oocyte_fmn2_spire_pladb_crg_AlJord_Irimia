#!/usr/bin/bash

##############################
# Full Processing Pipeline CRG Adel Manu Lab for Pladienolide B dataset
# This script processes the Pladienolide B dataset (unpublished) by performing the following steps:
# 1. Concatenate reads
# 2. Trim reads
# 3. Align reads
# 4. Generate a multiQC report
# 5. Run vast combine
# 6. Run vast compare
##############################

# SLURM output and error files
#SBATCH --output=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.out
#SBATCH --error=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.err

# First job - concatenate reads
echo "Submitting first job: Concatenate reads..."
jid1=$(sbatch $PWD/scripts/bash/processing1_cat_reads_pladb.sh | tr -cd '[:digit:].')
echo "...first job ID is $jid1"

# Second job - trim reads (dependent on first job)
echo "Submitting second job: Trim reads..."
jid2=$(sbatch --dependency=afterok:$jid1 $PWD/scripts/bash/processing2_trim_reads_pladb.sh | tr -cd '[:digit:].')
echo "...second job ID is $jid2"

# Third job - align reads (dependent on second job)
echo "Submitting third job: Align reads..."
jid3=$(sbatch --dependency=afterok:$jid2 $PWD/scripts/bash/vast_align_pladb.sh | tr -cd '[:digit:].')
echo "...third job ID is $jid3"

# Fourth job - generate multiQC report (dependent on third job)
echo "Submitting fourth job: Generate multiQC report..."
jid4=$(sbatch --dependency=afterok:$jid3 $PWD/scripts/bash/multiqc.sh | tr -cd '[:digit:].')
echo "...fourth job ID is $jid4"

# Fifth job - run vast combine (dependent on fourth job)
echo "Submitting fifth job: Run vast combine..."
jid5=$(sbatch --dependency=afterok:$jid4 $PWD/scripts/bash/vast_combine_pladb.sh | tr -cd '[:digit:].')
echo "...fifth job ID is $jid5"

# Sixth job - run vast compare (dependent on fifth job)
echo "Submitting sixth job: Run vast compare..."
jid6=$(sbatch --dependency=afterok:$jid5 $PWD/scripts/bash/vast_compare_pladb.sh | tr -cd '[:digit:].')
echo "...sixth job ID is $jid6"

echo "All jobs submitted!"