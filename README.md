# 24CRG_ADEL_MANU_OOCYTE_SPLICING
**Author**: Andrés Gordo Ortiz
**Institution**: Centre for Genomic Regulation (CRG)
**Supervisors**: Adel Al Jord, Manuel Irimia
**Project Type**: Master Thesis

## Project Overview

This repository consists on the data exploration, processing and plotting for the Oocyte Alternative Splicing Analysis after microtubule-related shaking inhibition for the ***Al Jord Lab @CRG*** during my master thesis. Specifically, differential analysis, simulation and Ontology exploration of mRNA splicing events were performed on three different experiments of mouse oocytes; splicing-modulator *Pladienolide B* treatment at two different doses (1mM and 10mM), *double knock-out of FMN2 F-actin nucleating factor*, and *double knock-out of the FMN2-interacting Spire protein*.

## Samples

## Repository Structure

- **config/**: Configuration files for Docker, and HPC cluster settings.
- **data/**: Raw, processed and metadata files. Raw and processed data are excluded from version control.
- **notebooks/**: Exploratory and analysis notebooks for VSCode and RStudio.
- **scripts/**: Custom scripts for data processing in Bash and downstream analysis in R.
- **workflows/**: Complete Pipelines to process the data from zero (no data in local) up to the finl Inclusion tables with all events. We recommend using *SLURM* for batch processing, otherwise the pipelines and scripts will have to be tweaked in order to work in your own implementation of work management.
- **docs/**: Documentation files, including installation instructions and workflow details.
- **.github/**: GitHub-specific workflows for continuous integration and issue templates.

## Processing Workflow

1. PladB and FMN2-/- technical replicates were first merged using *cat*.
2. All samples *fastq.gz* files were quality checked using fastQC and MultiQC [[1]](#1)
3. Reads were then **mapped** to the latest [mm10 build](https://vastdb.crg.eu/libs/vastdb.mm2.23.06.20.tar.gz) of the mouse genome using the Bowtie2 implementation of **Vast Tools**, which also allows for curated identification and quantification of splicing events. See [Vast-tools](https://github.com/vastgroup/vast-tools) for indications on how to manually download the builds [[2]](#2).
4. Inclusion Tables from each study were then transferred to RStudio for downstream processing. Simulations through the **Beta distribution** and statistical significance (*p-value <= 0.05*) for each splicing event were calculated using the [betAS](https://github.com/DiseaseTranscriptomicsLab/betAS/) package [[3]](#3).

## Installation and Setup
In order to run this repo without forking and modifying it, you will need access to a HPC Cluster which uses *SLURM* as the work manager and any Linux-based distribution as OS, although *AlmaLinux* was used in our case.

1. Clone the repository:
   ```bash
   # Clone the repository to your HPC folder
   git clone https://github.com/andresgordoortiz/24CRG_ADEL_MANU_OOCYTE_SPLICING.git
   cd 24CRG_ADEL_MANU_OOCYTE_SPLICING
   ```

2. Run the pipelines using *SLURM*. All code runs under online *Docker* images translated into Singularity *SIF* files. Therefore, no specific software needs to be installed beforehand.
   ```bash
   # Important: you must pass a suitable VASTDB database as absolute path to run the pipelines
   sbatch workflows/full_processing_pipeline_fmndko.sh /PATH_TO_VASTDB
   sbatch workflows/full_processing_pipeline_pladb.sh /PATH_TO_VASTDB
   sbatch workflows/full_processing_pipeline_spire.sh /PATH_TO_VASTDB
   ```

3. Run the RMarkdown Notebook
   ```bash
   sbatch scripts/R/run_notebook.sh

## Docker Containers used
1. Rmarkdown Processing: [andresgordoortiz/splicing_analysis_r_crg:v1.2](https://hub.docker.com/layers/andresgordoortiz/splicing_analysis_r_crg/v1.2/images/sha256-67fd933eb88fbb9e3fe099c18eef9926bcaf916f92ff0f1fd5f9e876f78fd726?context=repo)
2. Vast-Tools Alternative Splicing Analysis: [andresgordoortiz/vast-tools:latest](https://hub.docker.com/layers/andresgordoortiz/vast-tools/latest/images/sha256-e760bb36d7383ad9d9447035d09d1b282f52e8d44acf6a14ffc23ffcc3d7d383?context=repo)

## References
<a id="1">[1]</a>
Philip Ewels, Måns Magnusson, Sverker Lundin, Max Käller, MultiQC: summarize analysis results for multiple tools and samples in a single report, Bioinformatics, Volume 32, Issue 19, October 2016, Pages 3047–3048, https://doi.org/10.1093/bioinformatics/btw354

<a id="2">[2]</a>
Gohr, A., Mantica, F., Hermoso-Pulido, A., Tapial, J., Márquez, Y., Irimia, M. (2022). Computational Analysis of Alternative Splicing Using VAST-TOOLS and the VastDB Framework. In: Scheiffele, P., Mauger, O. (eds) Alternative Splicing. Methods in Molecular Biology, vol 2537. Humana, New York, NY. https://doi.org/10.1007/978-1-0716-2521-7_7

<a id="3">[3]</a>
Ascensão-Ferreira, M., Martins-Silva, R., Saraiva-Agostinho, N. & Barbosa-Morais, N. L. betAS: intuitive analysis and visualization of differential alternative splicing using beta distributions. RNA 30, 337 (2024).


sbatch scripts/submit_nf.sh
      nf-core/rnasplice
		 --input samplesheet_ssa_pladb_tub.csv
		 --contrasts contrastsheet.csv
		 --outdir nextflow_splicing/
		 --gtf /users/aaljord/agordo/git/24CRG_ADEL_MANU_MYOBLAST_SPLICING/gencode.vM36.primary_assembly.annotation.gtf
		 --fasta /users/aaljord/agordo/git/24CRG_ADEL_MANU_MYOBLAST_SPLICING/GRCm39.primary_assembly.genome.fa
		 --star_index /users/aaljord/agordo/git/24CRG_ADEL_MANU_MYOBLAST_SPLICING/GenomeDir/
		 --skip_trimming
		 --skip_fastqc
		 --rmats
		 --rmats_read_len 60
		 -with-tower
		 -profile crg