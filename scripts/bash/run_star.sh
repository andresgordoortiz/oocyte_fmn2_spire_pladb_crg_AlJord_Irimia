#!/bin/bash

##################
# slurm settings #
##################

# where to put stdout / stderr
#SBATCH --output=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.out
#SBATCH --error=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.err

# time limit in minutes
#SBATCH --time=300

# queue
#SBATCH --qos=short
#SBATCH --requeue

# memory (MB)
#SBATCH --mem=50G
#SBATCH --cpus-per-task=8

# job name
#SBATCH --job-name star-index-align

#################
# start message #
#################
# Define paths
FASTA="/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa"            # Path to mm10 genome FASTA
GTF="/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/Mus_musculus.GRCm39.113.gtf"        # Path to GTF annotation file
GENOME_DIR="/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/STAR/index"           # Directory to store STAR genome index
FASTQ="/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/data/processed/pladb/2022_038_S10_L001_R1_001_merged.fastq.gz"           # Path to input FASTQ file
OUTDIR="/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/STAR"         # Directory for alignment output


# Check if genome index exists
if [ ! -d "$GENOME_DIR" ]; then
    echo "Genome directory not found. Creating index at $GENOME_DIR..."

    mkdir -p "$GENOME_DIR"

    singularity exec --bind $PWD:$PWD docker://quay.io/biocontainers/star:2.7.11b--h5ca1c30_4 STAR \
        --runThreadN 8 \
        --runMode genomeGenerate \
        --genomeDir "$GENOME_DIR" \
        --genomeFastaFiles "$FASTA" \
        --sjdbGTFfile "$GTF" \

    echo "STAR genome index created successfully!"
else
    echo "Genome directory already exists. Skipping index creation."
fi

# Run STAR alignment
singularity exec --bind $PWD:$PWD docker://quay.io/biocontainers/star:2.7.11b--h5ca1c30_4 STAR \
    --runThreadN 8 \
    --genomeDir "$GENOME_DIR" \
    --readFilesIn "$FASTQ" \
    --readFilesCommand zcat \
    --outFileNamePrefix "$OUTDIR/sample" \
    --outSAMtype BAM SortedByCoordinate \
    --quantMode TranscriptomeSAM GeneCounts

echo "Alignment completed for sample $FASTQ"
