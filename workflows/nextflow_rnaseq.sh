#!/usr/bin/env bash
#SBATCH --no-requeue
#SBATCH --mem 6G
#SBATCH -p genoa64
#SBATCH --qos pipelines
#SBATCH --job-name nextflow_rnaseq
# where to put stdout / stderr
#SBATCH --output=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.out
#SBATCH --error=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.err
# Configure bash
set -e          # exit immediately on error
set -u          # exit immidiately if using undefined variables
set -o pipefail # ensure bash pipelines return non-zero status if any of their command fails

# Setup trap function to be run when canceling the pipeline job. It will propagate the SIGTERM signal
# to Nextlflow so that all jobs launche by the pipeline will be cancelled too.
_term() {
        echo "Caught SIGTERM signal!"
        kill -s SIGTERM $pid
        wait $pid
}

trap _term TERM

# load Java module
module load Java
module load Nextflow/24.04.3
# limit the RAM that can be used by nextflow
export NXF_JVM_ARGS="-Xms2g -Xmx5g"

# Run the pipeline. The command uses the arguments passed to this script, e.g:
#
# $ sbatch submit_nf.sh nextflow/rnatoy -with-singularity
#
# will use "nextflow/rnatoy -with-singularity" as arguments
nextflow run nf-core/rnaseq \
    -ansi-log false \
    --input $PWD/data/metadata/pladienolideb/rnaseq_input_pladb.csv \
    --outdir $PWD/rnaseq_out \
    --gtf $PWD/reference_genome/mouse/Mus_musculus.GRCm39.113.gtf.gz \
    --fasta $PWD/reference_genome/mouse/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa.gz \
    -c $PWD/config/nextflow_rnaseq.config \
    --save_reference \
    -with-singularity & pid=$!

# Wait for the pipeline to finish
echo "Waiting for ${pid}"
wait $pid

# Return 0 exit-status if everything went well
exit 0