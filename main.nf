#!/usr/bin/env nextflow

/*
==========================================
 FMN2/Spire Alternative Splicing Analysis Pipeline
==========================================
 Authors: Andrés Gordo
 Date: April 2025

 Description:
 This pipeline processes RNA-Seq data to analyze alternative splicing patterns in FMN2/Spire knockouts using VAST-tools.
*/

nextflow.enable.dsl=2

// Default parameters
params.outdir = "$projectDir/nextflow_results"
params.vastdb_path = "/path/to/vastdb"
params.reads_dir = null  // This is now mandatory
params.help = false
params.skip_fastqc = false  // Option to skip FastQC step
params.rmd_file = "$projectDir/scripts/R/notebooks/Oocyte_fmndko_spireko_complete.Rmd"
params.prot_impact_url = "https://vastdb.crg.eu/downloads/mm10/PROT_IMPACT-mm10-v3.tab.gz"
params.species = "mm10"  // Default species for VAST-tools alignment

// Define parameter validation function
def validateParameters() {
    if (params.vastdb_path == "/path/to/vastdb") {
        log.error "ERROR: No path to VAST-DB has been specified. Please set the --vastdb_path parameter to the location of your VAST-DB directory (e.g., --vastdb_path /path/to/vastdb)."
        exit 1
    }

    if (params.reads_dir == null) {
        log.error "ERROR: No reads directory has been specified. Please set the --reads_dir parameter to the location of your FASTQ files (e.g., --reads_dir /path/to/fastq)."
        exit 1
    }

    def readsDir = file(params.reads_dir)
    if (!readsDir.exists() || !readsDir.isDirectory()) {
        log.error "ERROR: The specified reads directory '${params.reads_dir}' does not exist or is not a directory. Please verify the path."
        exit 1
    }

    // Check for fastq files in the reads directory
    def fastqFiles = readsDir.listFiles().findAll { it.name.endsWith('.fastq.gz') }
    if (fastqFiles.size() == 0) {
        log.error "ERROR: No .fastq.gz files found in the specified reads directory: ${params.reads_dir}"
        exit 1
    }
}


process concatenate_reads {
    tag "Concatenating read files in triples"
    label 'process_medium'
    // No publishDir directive as we don't want to publish these files

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

process prepare_vastdb {
    tag "Prepare VASTDB"

    input:
    val vastdb_path

    output:
    path "local_vastdb", emit: local_vastdb_dir

    script:
    """
    echo "Creating a local copy of VASTDB from ${vastdb_path}"
    mkdir -p local_vastdb

    if [ -d "${vastdb_path}" ]; then
        echo "Copying VASTDB content from ${vastdb_path}"
        cp -r ${vastdb_path}/* local_vastdb/ || echo "Warning: Some files could not be copied"

        # Create the specific species directory structure if it doesn't exist
        mkdir -p local_vastdb/Mm2

        # Check what was copied
        echo "Local VASTDB contents:"
        ls -la local_vastdb/
        find local_vastdb -type d | sort
    else
        echo "ERROR: Source VASTDB directory ${vastdb_path} not found!"
        echo "Creating minimal directory structure"
        mkdir -p local_vastdb/Mm2
        mkdir -p local_vastdb/TEMPLATES
        touch local_vastdb/VASTDB.VERSION
    fi
    """
}

process align_reads {
    tag "VAST-tools alignment"
    label 'process_high'
    debug true

    input:
    path processed_dir
    path local_vastdb_dir

    output:
    path "vast_out", emit: vast_out_dir

    script:
    """
    mkdir -p vast_out
    echo "Starting VAST-tools alignment..."

    echo "Using local VASTDB copy at: \$PWD/${local_vastdb_dir}"
    echo "VASTDB structure:"
    find ${local_vastdb_dir} -type d | sort

    # Process each file with enhanced error handling
    for file in ${processed_dir}/*.fastq.gz; do
        basename=\$(basename \$file .fastq.gz)
        echo "Processing sample: \$basename"

        # Use local_vastdb instead of the container's default path
        VASTDB=\$PWD/${local_vastdb_dir} vast-tools align "\$file" -sp ${params.species} -o vast_out --IR_version 2 -c ${task.cpus} -n "\$basename" --verbose || {
            echo "Alignment failed for \$basename - trying to understand why:"
            echo "VAST-tools configuration:"
            VASTDB=\$PWD/${local_vastdb_dir} vast-tools --version || true
            exit 1;
        }
    done

    echo "VAST-tools alignment complete."
    """
}

process combine_results {
    tag "VAST-tools combine"
    label 'process_medium'
    debug true
    publishDir "${params.outdir}/inclusion_tables", mode: 'copy', pattern: '*INCLUSION_LEVELS_FULL*.tab'

    input:
    path vast_out_dir
    path local_vastdb_dir

    output:
    path "fmndko_INCLUSION_LEVELS_FULL-mm10.tab", optional: true, emit: inclusion_table

    script:
    """
    echo "Using local VASTDB at: \$PWD/${local_vastdb_dir}"

    echo "Contents of vast_out directory:"
    ls -la ${vast_out_dir}/

    # Check if to_combine directory exists
    if [ ! -d "${vast_out_dir}/to_combine" ]; then
        echo "WARNING: to_combine directory not found in ${vast_out_dir}"
        echo "Contents of ${vast_out_dir}:"
        find ${vast_out_dir} -type d | sort
        echo "Creating empty to_combine directory as fallback"
        mkdir -p ${vast_out_dir}/to_combine
    fi

    echo "Combining VAST-tools results..."
    VASTDB=\$PWD/${local_vastdb_dir} vast-tools combine ${vast_out_dir}/to_combine -sp ${params.species} -o ${vast_out_dir} || {
        echo "VAST-tools combine failed - debugging:"
        VASTDB=\$PWD/${local_vastdb_dir} vast-tools --version
        exit 1;
    }

    inclusion_file=\$(find ${vast_out_dir} -name "INCLUSION_LEVELS_FULL*" | head -n 1)
    if [ -n "\$inclusion_file" ];then
        cp "\$inclusion_file" fmndko_INCLUSION_LEVELS_FULL-mm10.tab
        echo "✓ Results successfully combined and inclusion table created"
    else
        echo "WARNING: No INCLUSION_LEVELS_FULL file was created."
        touch fmndko_INCLUSION_LEVELS_FULL-mm10.tab  # Create an empty placeholder file
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
    FILE3="notebooks/PROT_IMPACT-mm10-v2.3.tab.gz"
    UNZIPPED_FILE3="\${FILE3%.gz}"

    if [ ! -f "\$UNZIPPED_FILE3" ]; then
        if [ ! -f "\$FILE3" ];then
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

    // Execute processes in order with proper logging
    log.info "Starting pipeline execution..."

    // Create a channel from the reads directory
    reads_dir = Channel.fromPath(params.reads_dir, checkIfExists: true, type: 'dir')

    // Prepare VASTDB - this is the new process
    local_vastdb_dir = prepare_vastdb(params.vastdb_path)

    // Run processes in sequence with proper channel connections
    verify_files(reads_dir)
    processed_dir = concatenate_reads(reads_dir)

    // Run FastQC on processed reads if not skipped
    if (!params.skip_fastqc) {
        run_fastqc(processed_dir)
    } else {
        log.info "Skipping FastQC step as per user request."
    }

    // Align reads using the local VASTDB copy
    vast_out_dir = align_reads(processed_dir, local_vastdb_dir)

    // Combine results after alignment using the local VASTDB copy
    inclusion_table = combine_results(vast_out_dir, local_vastdb_dir)

    // Run the Rmarkdown report
    run_rmarkdown_report(inclusion_table)
}