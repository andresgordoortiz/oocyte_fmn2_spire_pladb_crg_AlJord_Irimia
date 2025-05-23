#!/usr/bin/env bash

#SBATCH --no-requeue

#SBATCH --mem 6G

#SBATCH -p genoa64

#SBATCH --qos pipelines



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

module load Nextflow

module load Java



# Check if we're running in a SLURM environment

if [ -n "$SLURM_JOB_ID" ]; then

    echo "Running as SLURM job ID: $SLURM_JOB_ID"

    echo "SLURM_CONF is set to: $SLURM_CONF"

else

    echo "Warning: Not running as a SLURM job. Process distribution may be limited."

fi



# Ensure SLURM_CONF is available to child processes

export SLURM_CONF=${SLURM_CONF:-/etc/slurm/slurm.conf}

echo "Using SLURM configuration: $SLURM_CONF"



# Make absolutely sure Nextflow sees this is a SLURM environment

export NXF_EXECUTOR=slurm

export NXF_CLUSTER_SEED=531684



# Ensure all relevant SLURM environment variables are preserved and passed to Nextflow

export SLURM_EXPORT_ENV=ALL



# limit the RAM that can be used by nextflow

export NXF_JVM_ARGS="-Xms2g -Xmx5g -Dexecutor.name=slurm"



# Debug output

echo "Environment variables for Nextflow:"

env | grep -E 'SLURM|NXF'



# Create a custom config to force SLURM executor

cat <<EOF > nextflow_executor_override.config

executor {

  name = 'slurm'

}

process.executor = 'slurm'

EOF



# Always add the -profile crg parameter and executor override unless it's already specified

if [[ "$@" != *"-profile"* ]] && [[ "$@" != *"-config"* ]]; then

    echo "Adding -profile crg and executor=slurm to nextflow command"

    nextflow run -ansi-log false -profile crg -c nextflow_executor_override.config --executor slurm -with-trace "$@" & pid=$!

else

    echo "Running with existing profile/config setting plus executor=slurm"

    nextflow run -ansi-log false -c nextflow_executor_override.config --executor slurm -with-trace "$@" & pid=$!

fi



# Wait for the pipeline to finish

echo "Waiting for Nextflow process ${pid}"

wait $pid



# Print executor information from the trace file if available

if [ -f "trace.txt" ]; then

    echo "Executor information from trace file:"

    head -n 1 trace.txt

    grep -m 1 "executor" trace.txt || echo "No executor info found in trace file"

fi



# Return 0 exit-status if everything went well

exit 0
