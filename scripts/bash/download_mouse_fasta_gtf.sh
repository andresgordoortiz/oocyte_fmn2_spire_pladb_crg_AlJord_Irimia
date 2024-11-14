#!/bin/bash
mkdir -p $PWD/reference_genome/mouse
# Define URLs for the mouse FASTA and GTF files
FASTA_URL="https://ftp.ensembl.org/pub/release-113/fasta/mus_musculus/dna/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa.gz"
GTF_URL="https://ftp.ensembl.org/pub/release-113/gtf/mus_musculus/Mus_musculus.GRCm39.113.gtf.gz"
# Download the mouse FASTA file
wget -O $PWD/reference_genome/mouse/Mus_musculus.GRCm39.dna_sm.primary_assembly.fa.gz $FASTA_URL

# Download the mouse GTF file
wget -O $PWD/reference_genome/mouse/Mus_musculus.GRCm39.113.gtf.gz $GTF_URL
