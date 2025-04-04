#!/usr/bin/env nextflow

/*
==========================================
 FMN2/Spire Alternative Splicing Analysis Pipeline
==========================================
 Authors: Andrés Gordo
 Date: April 2025

 Description:
 This pipeline processes RNA-Seq data to analyze alternative splicing patterns in FMN2/Spire knockouts using VAST-tools. It includes steps for downloading or linking FASTQ files, concatenating reads, performing quality control, aligning reads, combining results, and generating an RMarkdown report.

 Dependencies:
 - Nextflow
 - VAST-tools
 - FastQC
 - R with rmarkdown package

 Expected Outputs:
 - Processed FASTQ files
 - Quality control reports
 - VAST-tools alignment results
 - Combined inclusion level tables
 - HTML report summarizing the analysis
*/

nextflow.enable.dsl=2

// Default parameters
params.outdir = "$projectDir/nextflow_results"
params.vastdb_path = "/path/to/vastdb"
params.script_file = "$projectDir/data/raw/fmndko/fmndko_PRJNA406820.sh"
params.help = false
params.skip_fastqc = false  // Option to skip FastQC step
params.rmd_file = "$projectDir/scripts/R/notebooks/Oocyte_fmndko_spireko_complete.Rmd"
params.prot_impact_url = "https://vastdb.crg.eu/downloads/mm10/PROT_IMPACT-mm10-v3.tab.gz"  // Default URL for PROT_IMPACT file
params.reads_dir = null  // If specified, use existing FASTQ files instead of downloading
params.species = "mm10"  // Default species for VAST-tools alignment

// Define parameter validation function
def validateParameters() {
    if (params.vastdb_path == "/path/to/vastdb") {
        log.error "ERROR: No path to VAST-DB has been specified. Please set the --vastdb_path parameter to the location of your VAST-DB directory (e.g., --vastdb_path /path/to/vastdb)."
        exit 1
    }
}

process download_reads {
    tag "Downloading FASTQ files"
    label 'process_medium'
    publishDir "${params.outdir}/raw_data", mode: 'copy', pattern: 'raw_data'

    output:
    path "raw_data", emit: raw_dir

    script:
    if (params.reads_dir) {
        // If a reads directory is provided, use it
        """
        mkdir -p raw_data
        echo "Using pre-downloaded FASTQ files from ${params.reads_dir}"

        # Use more robust file finding and copying
        FASTQ_FILES=\$(find "${params.reads_dir}" -name "*.fastq.gz")
        if [ -z "\$FASTQ_FILES" ]; then
            echo "ERROR: No FASTQ files found in ${params.reads_dir}"
            exit 1
        fi

        # Copy each file individually
        for file in \$FASTQ_FILES; do
            cp "\$file" raw_data/
            echo "Copied \$(basename \$file)"
        done

        # Verify files were copied correctly
        file_count=\$(find raw_data -name "*.fastq.gz" | wc -l)
        echo "Found \$file_count FASTQ files in the raw_data directory"

        if [ \$file_count -eq 0 ]; then
            echo "ERROR: No FASTQ files found or copied from ${params.reads_dir}"
            exit 1
        fi
        """
    } else {
        // Otherwise, download files using the script
        """
        if ! grep -q 'wget.*gz' ${params.script_file}; then
            echo "ERROR: The script file ${params.script_file} does not contain valid wget commands."
            exit 1
        fi

        grep -oP 'wget.*gz' ${params.script_file} | while read cmd; do
        cd raw_data
        echo "Downloading FASTQ files..."

        # Extract and run wget commands from the script file
        grep -oP 'wget.*gz' ${params.script_file} | while read cmd; do
            echo "Executing: \$cmd"
            eval \$cmd
        done

        # Verify downloads were successful
        file_count=\$(find . -name "*.fastq.gz" | wc -l)
        echo "Downloaded \$file_count FASTQ files"

        if [ \$file_count -eq 0 ]; then
            echo "ERROR: No files were downloaded!"
            exit 1
        fi

        cd ..
        """
    }
}

process concatenate_reads {
    tag "Concatenating read files in triples"
    label 'process_medium'
    publishDir "${params.outdir}/processed", mode: 'copy', pattern: 'processed_files'

    input:
    path raw_dir

    output:
    path "processed_files", emit: processed_dir

    script:
    """
    mkdir -p processed_files

    echo "Starting to concatenate read files in triples..."

    # List all fastq.gz files in the input directory
    ls -1 ${raw_dir}/*.fastq.gz > all_fastq_files.txt || {
        echo "ERROR: No fastq.gz files found in ${raw_dir}!"
        exit 1
    }

    # Count total files and create an array
    total_files=\$(wc -l < all_fastq_files.txt)
    echo "Found \$total_files fastq.gz files to process"

    # Check if we have files to process
    if [ \$total_files -eq 0 ]; then
        echo "ERROR: No fastq.gz files found to process!"
        exit 1
    fi

    # Read files into array
    i=1
    files=()
    while read -r file; do
        files[\$((i-1))]="\$file"
        i=\$((i+1))
    done < all_fastq_files.txt

    # Iterate over the files in triples
    for ((i=0; i<\$total_files; i+=3)); do
        # Check if we have a complete triple
        if [ \$((i+2)) -lt \$total_files ]; then
            # We have a complete triple
            file1=\${files[i]}
            file2=\${files[i+1]}
            file3=\${files[i+2]}

            # Get basenames for the three files
            base1=\$(basename \$file1 .fastq.gz)
            base2=\$(basename \$file2 .fastq.gz)
            base3=\$(basename \$file3 .fastq.gz)

            # Define the output file name
            output_file="processed_files/\${base1}_\${base2}_\${base3}_merged.fastq.gz"

            echo "Merging files \$((i+1))-\$((i+3)) of \$total_files:"
            echo " 1: \$(basename \$file1)"
            echo " 2: \$(basename \$file2)"
            echo " 3: \$(basename \$file3)"

            # Concatenate the triple of files
            cat "\$file1" "\$file2" "\$file3" > "\$output_file"

            echo "✓ Created merged file: \$(basename \$output_file)"
        else
            # Handle remaining files (incomplete triple) if any
            echo "WARNING: Remaining files will not be processed in this implementation"
        fi
    done

    # Count processed files
    processed_count=\$(ls -1 processed_files/*.fastq.gz 2>/dev/null | wc -l)
    echo "Concatenation complete. \$processed_count merged files created."

    # Make sure we have files
    if [ \$processed_count -eq 0 ]; then
        echo "ERROR: No files were processed!"
        exit 1
    fi
    """
}

process verify_files {
    debug true

    input:
    path dir

    script:
    """
    echo "Verifying directory contents: ${dir}"
    echo "File count: \$(find ${dir} -type f | wc -l)"
    find ${dir} -type f | head -n 5
    """
}

process run_fastqc {
    tag "Quality control"
    label 'process_medium'
    publishDir "${params.outdir}/qc", mode: 'copy', pattern: 'fastqc_output'

    input:
    path processed_dir

    output:
    path "fastqc_output", emit: fastqc_dir

    script:
    """
    mkdir -p fastqc_output
    echo "Running FastQC quality control..."
    fastqc -t ${task.cpus} -o fastqc_output ${processed_dir}/*.fastq.gz
    echo "FastQC analysis complete."
    """
}

process align_reads {
    tag "VAST-tools alignment"
    label 'process_high'
    publishDir "${params.outdir}/vast_align", mode: 'copy', pattern: 'vast_out'

    input:
    path processed_dir
    val vastdb_path

    output:
    path "vast_out", emit: vast_out_dir

    script:
    """
    mkdir -p vast_out
    echo "Starting VAST-tools alignment..."

    for file in ${processed_dir}/*.fastq.gz; do
        basename=\$(basename \$file .fastq.gz)
        echo "Processing sample: \$basename"
        vast-tools align "\$file" -sp ${params.species} -o vast_out --IR_version 2 -c ${task.cpus} -n "\$basename" -dbDir /usr/local/vast-tools/VASTDB || { echo "Alignment failed for \$basename"; exit 1; }
    done

    echo "VAST-tools alignment complete."
    """
}

process combine_results {
    tag "VAST-tools combine"
    label 'process_medium'
    publishDir "${params.outdir}/inclusion_tables", mode: 'copy', pattern: '*INCLUSION_LEVELS_FULL*.tab'

    input:
    path vast_out_dir
    val vastdb_path

    output:
    path "fmndko_INCLUSION_LEVELS_FULL-mm10.tab", optional: true, emit: inclusion_table

    script:
    """
    echo "Combining VAST-tools results..."
    vast-tools combine ${vast_out_dir}/to_combine -sp mm10 -o ${vast_out_dir} || { echo "VAST-tools combine failed"; exit 1; }

    inclusion_file=\$(find ${vast_out_dir} -name "INCLUSION_LEVELS_FULL*" | head -n 1)
    if [ -n "\$inclusion_file" ]; then
        cp "\$inclusion_file" fmndko_INCLUSION_LEVELS_FULL-mm10.tab
        echo "✓ Results successfully combined and inclusion table created"
    else
        echo "WARNING: No INCLUSION_LEVELS_FULL file was created. Skipping this step."
        touch fmndko_INCLUSION_LEVELS_FULL-mm10.tab  # Create an empty placeholder file
    fi
    fi
    """
}

process run_rmarkdown_report {
    tag "Generate R analysis report"
    label 'process_high'
    publishDir "${params.outdir}/report", mode: 'copy', pattern: '*.html'


    input:
    path inclusion_table

    output:
    path "Oocyte_fmndko_spireko_complete.html", optional: true

    script:
    """
    # Create notebooks directory
    mkdir -p notebooks

    URL3="${params.prot_impact_url}"
    URL3="https://vastdb.crg.eu/downloads/mm10/PROT_IMPACT-mm10-v3.tab.gz"
    FILE3="notebooks/PROT_IMPACT-mm10-v2.3.tab.gz"
    UNZIPPED_FILE3="\${FILE3%.gz}"

    if [ ! -f "\$UNZIPPED_FILE3" ]; then
        if [ ! -f "\$FILE3" ]; then
            echo "\$FILE3 not found. Downloading..."
            wget "\$URL3" -O "\$FILE3"
        else
            echo "\$FILE3 already exists. Skipping download."
        fi
        echo "Unzipping \$FILE3..."
        gunzip -c "\$FILE3" > "\$UNZIPPED_FILE3"
    else
        echo "\$UNZIPPED_FILE3 already exists. Skipping download and unzip."
    fi

    # Copy inclusion table to notebooks directory
    cp ${inclusion_table} notebooks/
    # Verify the RMarkdown file exists
    RMD_FILE="\$PWD/notebooks/Oocyte_fmndko_spireko_complete.Rmd"
    if [ ! -f "\$RMD_FILE" ]; then
        echo "ERROR: RMarkdown file \$RMD_FILE not found. Cannot generate the report."
        exit 1
    fi

    # Run the RMarkdown report
    cd /
    Rscript -e "rmarkdown::render('\$RMD_FILE')"
    Rscript -e "rmarkdown::render('\$PWD/notebooks/Oocyte_fmndko_spireko_complete.Rmd')"

    # Move the HTML report from notebooks to current directory
    cp notebooks/Oocyte_fmndko_spireko_complete.html ./
    """
}

// Add a workflow block to define the execution flow
workflow {
    // Validate parameters first
    validateParameters()

    // Get the download script
    download_script = file(params.script_file)
    if (!download_script.exists()) {
        error "ERROR: The specified download script file '${params.script_file}' does not exist or is inaccessible. Please verify that the path is correct and the file is readable. Example: --script_file /path/to/your_script.sh"
    }

    // Execute processes in order with proper logging
    log.info "Starting pipeline execution..."

    // Run processes in sequence with proper channel connections
    raw_dir = download_reads()
    verify_files(raw_dir)

    processed_dir = concatenate_reads(raw_dir)

    // Run FastQC on processed reads if not skipped
    if (!params.skip_fastqc) {
        run_fastqc(processed_dir)
    } else {
        log.info "Skipping FastQC step as per user request."
    }

    // Align reads
    vast_out_dir = align_reads(processed_dir, params.vastdb_path)

    // Combine results after alignment
    inclusion_table = combine_results(vast_out_dir, params.vastdb_path)

    // Run the Rmarkdown report
    run_rmarkdown_report(inclusion_table)
}