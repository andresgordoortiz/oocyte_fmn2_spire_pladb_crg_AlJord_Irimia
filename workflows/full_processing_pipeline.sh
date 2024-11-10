#!/usr/bin/bash
# where to put stdout / stderr
#SBATCH --output=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.out
#SBATCH --error=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.err
# run a pipeline made up of a sequence of 2 separate jobs

# first job - process fastqs to find kmers
echo submitting first job...
jid1=$(sbatch $PWD/scripts/bash/processing1_cat_reads.sh | tr -cd '[:digit:].')
echo ...first job id is $jid1

# second job - collate partial answers from first job into
echo submitting second job...
jid2=$(sbatch --dependency=afterok:$jid1 $PWD/scripts/bash/processing2_trim_reads.sh | tr -cd '[:digit:].')
echo ...second job id is $jid2

echo submitting third job...
jid3=$(sbatch --dependency=afterok:$jid2 $PWD/scripts/bash/multiqc.sh | tr -cd '[:digit:].')
echo ...second job id is $jid3