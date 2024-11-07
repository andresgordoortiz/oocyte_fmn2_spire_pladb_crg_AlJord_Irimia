#!/usr/bin/env bash

# job name
#SBATCH --job-name fetchngs

#SBATCH --no-requeue
#SBATCH --mem 10G
#SBATCH -p genoa64
#SBATCH --qos pipelines
#SBATCH --cpus-per-task=4
# where to put stdout / stderr
#SBATCH --output=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%j.out
#SBATCH --error=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%j.err

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
module load Nextflow

# limit the RAM that can be used by nextflow
export NXF_JVM_ARGS="-Xms2g -Xmx5g"

# Run the pipeline. The command uses the arguments passed to this script, e.g:
#
# $ sbatch submit_nf.sh nextflow/rnatoy -with-singularity
#
# will use "nextflow/rnatoy -with-singularity" as arguments
nextflow run -ansi-log false "$@" -c /users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/config/nextflow_fetchngs.config --max_cpus 4 & pid=$!

# Wait for the pipeline to finish
echo "Waiting for ${pid}"
wait $pid

# Return 0 exit-status if everything went well
exit 0