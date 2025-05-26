#!/usr/bin/env nextflow

/*
==========================================
 VAST-TOOLS Splicing Analysis Pipeline
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
params.sample_csv = null   // CSV file with sample info (replaces reads_dir)
params.help = false
params.skip_fastqc = false  // Option to skip FastQC step
params.skip_trimming = false  // Option to skip trimming step
params.skip_fastqc_in_trimming = false  // Option to skip FastQC within trim_galore
params.skip_rmarkdown = false  // Option to skip the final Rmarkdown report
params.rmd_file = "$projectDir/scripts/R/notebooks/Oocyte_fmndko_spireko_complete.Rmd"
params.prot_impact_url = "https://vastdb.crg.eu/downloads/mm10/PROT_IMPACT-mm10-v3.tab.gz"
params.species = "mm10"  // Default species for VAST-tools alignment
params.multiqc_config = null  // Path to multiqc config file (optional)

// Change from default value to null to make it mandatory
params.data_dir = null  // Now mandatory - directory containing input FASTQ files

// Display help message
def helpMessage() {
    log.info"""
    ============================================================
     FMN2/SPIRE ALTERNATIVE SPLICING ANALYSIS PIPELINE
    ============================================================
    Usage:

    nextflow run main.nf --sample_csv sample_sheet.csv --vastdb_path /path/to/vastdb --data_dir /path/to/data

    Mandatory Arguments:
      --sample_csv          Path to CSV file defining samples to analyze
      --vastdb_path         Path to VASTDB directory
      --data_dir            Path to directory containing FASTQ files referenced in sample_csv

    Sample CSV Format:
      The CSV file should contain the following columns:
      - sample: Unique sample identifier (required)
      - fastq_1: Path to FASTQ file (R1 for paired-end data) (required)
      - fastq_2: Path to FASTQ file for R2 (required for paired-end data)
      - type: One of 'single', 'paired', 'technical_replicate' (required)
      - group: Group identifier for the sample (optional)

      For technical replicates, additional columns (fastq_3, fastq_4, etc.) can
      be added to define more files to concatenate.

    Optional Arguments:
      --outdir              Output directory (default: ${params.outdir})
      --species             Species for VAST-tools alignment (default: ${params.species})
      --skip_fastqc         Skip FastQC quality control (default: ${params.skip_fastqc})
      --skip_trimming       Skip trimming of reads (default: ${params.skip_trimming})
      --skip_fastqc_in_trimming  Skip FastQC within trim_galore (default: ${params.skip_fastqc_in_trimming})
      --skip_rmarkdown      Skip RMarkdown report generation (default: ${params.skip_rmarkdown})
      --rmd_file            Path to RMarkdown file for report (default: ${params.rmd_file})
      --multiqc_config      Path to MultiQC config file (default: none)

    Example Command:
      nextflow run main.nf --sample_csv samples.csv --vastdb_path /path/to/vastdb --data_dir /path/to/data --species mm10 --outdir results
    ============================================================
    """.stripIndent()
}

// Help message function is defined above, will be called from the workflow

// Define parameter validation function
def validateParameters() {
    if (params.vastdb_path == "/path/to/vastdb") {
        log.error "ERROR: No path to VAST-DB has been specified. Please set the --vastdb_path parameter to the location of your VAST-DB directory (e.g., --vastdb_path /path/to/vastdb)."
        exit 1
    }

    if (params.sample_csv == null) {
        log.error "ERROR: No sample CSV file has been specified. Please set the --sample_csv parameter to the location of your sample sheet CSV file (e.g., --sample_csv /path/to/samples.csv)."
        exit 1
    }

    if (params.data_dir == null) {
        log.error "ERROR: No data directory has been specified. Please set the --data_dir parameter to the location containing your FASTQ files (e.g., --data_dir /path/to/fastq_files)."
        exit 1
    }

    def dataDir = file(params.data_dir)
    if (!dataDir.exists()) {
        log.error "ERROR: The specified data directory '${params.data_dir}' does not exist. Please verify the path."
        exit 1
    }

    if (!dataDir.isDirectory()) {
        log.error "ERROR: The specified path '${params.data_dir}' is not a directory."
        exit 1
    }

    def sampleCsv = file(params.sample_csv)
    if (!sampleCsv.exists()) {
        log.error "ERROR: The specified sample CSV file '${params.sample_csv}' does not exist. Please verify the path."
        exit 1
    }

    // Validate RMarkdown file if not skipping
    if (!params.skip_rmarkdown) {
        def rmdFile = file(params.rmd_file)
        if (!rmdFile.exists()) {
            log.warn "WARNING: The specified RMarkdown file '${params.rmd_file}' does not exist. RMarkdown report will be skipped."
            params.skip_rmarkdown = true
        }
    }

    // Check if the CSV file is properly formatted (header check)
    def firstLine = sampleCsv.withReader { it.readLine() }
    def requiredColumns = ['sample', 'fastq_1', 'type']
    def headers = firstLine.split(',').collect { it.trim().toLowerCase() }

    def missingColumns = requiredColumns.findAll { !headers.contains(it) }
    if (missingColumns) {
        log.error "ERROR: The sample CSV is missing required columns: ${missingColumns.join(', ')}."
        log.error "Required format: sample,fastq_1,fastq_2,type,group"
        log.error "Where type must be 'single', 'paired', or 'technical_replicate'"
        exit 1
    }

    // Additional validation: Check that paired samples have fastq_2
    def csvData = sampleCsv.withReader { reader ->
        reader.readLines().drop(1) // Skip header
    }

    csvData.each { line ->
        def values = line.split(',')
        if (values.size() >= 4 && values[3].trim().toLowerCase() == 'paired') {
            if (values.size() < 3 || !values[2] || values[2].trim().isEmpty()) {
                log.error "ERROR: Sample '${values[0]}' is marked as 'paired' but missing fastq_2 column or value."
                exit 1
            }
        }
    }
}


process concatenate_technical_replicates {
    tag "Concatenating technical replicates: ${sample_id}"
    label 'process_medium'

    // Resource requirements
    cpus 4
    memory { 4.GB }
    time { 30.min }

    input:
    tuple val(sample_id), val(sample_type), path(fastq_files), val(group)

    output:
    tuple val(sample_id), val('single'), path("${sample_id}.fastq.gz"), val(group), emit: sample_data

    when:
    sample_type == 'technical_replicate'

    script:
    """
    echo "Concatenating ${fastq_files.size()} technical replicate files for sample ${sample_id}..."
    cat ${fastq_files.join(' ')} > ${sample_id}.fastq.gz
    echo "✓ Created merged file for ${sample_id}"
    """
}

// Process to handle paired-end reads
process prepare_paired_reads {
    tag "Preparing paired-end reads: ${sample_id}"

    // Resource requirements
    cpus 1
    memory { 2.GB }
    time { 10.min }

    input:
    tuple val(sample_id), val(sample_type), path(fastq_files), val(group)

    output:
    tuple val(sample_id), val('paired'), path("${sample_id}_R{1,2}.fastq.gz"), val(group), emit: sample_data

    when:
    sample_type == 'paired'

    script:
    """
    # Link files with standard names for downstream processing
    ln -s ${fastq_files[0]} ${sample_id}_R1.fastq.gz
    ln -s ${fastq_files[1]} ${sample_id}_R2.fastq.gz
    """
}

// Process to handle single-end reads
process prepare_single_reads {
    tag "Preparing single-end reads: ${sample_id}"

    // Resource requirements
    cpus 1
    memory { 2.GB }
    time { 10.min }

    input:
    tuple val(sample_id), val(sample_type), path(fastq_files), val(group)

    output:
    tuple val(sample_id), val('single'), path("${sample_id}.fastq.gz"), val(group), emit: sample_data

    when:
    sample_type == 'single'

    script:
    """
    # Link file with standard name for downstream processing
    ln -s ${fastq_files[0]} ${sample_id}.fastq.gz
    """
}

process verify_files {
    debug true

    // Resource requirements
    cpus 1
    memory { 1.GB }
    time { 5.min }

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
    tag "Quality control: ${sample_id}"
    label 'process_medium'
    publishDir "${params.outdir}/qc/fastqc", mode: 'copy'
    container 'quay.io/biocontainers/fastqc:0.11.9--0' // Using biocontainer for FastQC

    // Resource requirements
    cpus 4
    memory { 8.GB }
    time { 1.hour }

    input:
    tuple val(sample_id), val(sample_type), path(fastq_files), val(group)

    output:
    path "*_fastqc.{zip,html}", emit: fastqc_results

    script:
    """
    echo "Running FastQC quality control on sample ${sample_id}..."
    fastqc -t ${task.cpus} ${fastq_files}
    echo "FastQC analysis complete for ${sample_id}."
    """
}

process run_trim_galore {
    tag "Trimming: ${sample_id}"
    label 'process_medium'
    publishDir "${params.outdir}/trimmed_reads", mode: 'copy', pattern: "*.{fq.gz,fastq.gz}"
    publishDir "${params.outdir}/qc/trimming_reports", mode: 'copy', pattern: "*_trimming_report.txt"
    publishDir "${params.outdir}/qc/fastqc_trimmed", mode: 'copy', pattern: "*_fastqc.{html,zip}"
    container 'https://depot.galaxyproject.org/singularity/trim-galore:0.6.9--hdfd78af_0' // Using galaxyproject container for trim_galore

    // Resource requirements
    cpus 4
    memory { 16.GB }
    time { 2.hours }

    input:
    tuple val(sample_id), val(sample_type), path(fastq_files), val(group)

    output:
    tuple val(sample_id), val(sample_type), path("*_trimmed.{fq.gz,fastq.gz}"), val(group), emit: trimmed_reads
    path "*_trimming_report.txt", emit: trim_log
    path "*_fastqc.{zip,html}", optional: true, emit: fastqc_results

    script:
    def fastqc_option = params.skip_fastqc_in_trimming ? "" : "--fastqc"
    def fastqc_args = params.skip_fastqc_in_trimming ? "" : "--fastqc_args '-t ${task.cpus}'"

    if (sample_type == 'paired') {
        // For paired-end data
        """
        echo "Trimming paired-end reads for sample ${sample_id}..."
        trim_galore ${fastqc_option} -j ${task.cpus} ${fastqc_args} \\
            --paired --quality 20 ${fastq_files[0]} ${fastq_files[1]} \\
            --basename ${sample_id}

        # More robust renaming with error checking
        if [ -f "${sample_id}_val_1.fq.gz" ]; then
            mv "${sample_id}_val_1.fq.gz" "${sample_id}_R1_trimmed.fq.gz"
        else
            echo "ERROR: Expected output file ${sample_id}_val_1.fq.gz not found"
            ls -la
            exit 1
        fi

        if [ -f "${sample_id}_val_2.fq.gz" ]; then
            mv "${sample_id}_val_2.fq.gz" "${sample_id}_R2_trimmed.fq.gz"
        else
            echo "ERROR: Expected output file ${sample_id}_val_2.fq.gz not found"
            ls -la
            exit 1
        fi

        echo "Trimming complete for ${sample_id}."
        """
    } else {
        // For single-end data - fix the naming logic
        """
        echo "Trimming single-end reads for sample ${sample_id}..."
        trim_galore ${fastqc_option} -j ${task.cpus} ${fastqc_args} \\
            --quality 20 ${fastq_files}

        # More robust file renaming
        TRIMMED_FILE=\$(find . -name "*_trimmed.fq.gz" -o -name "*_trimmed.fastq.gz" | head -n 1)
        if [ -n "\$TRIMMED_FILE" ]; then
            mv "\$TRIMMED_FILE" "${sample_id}_trimmed.fq.gz"
        else
            echo "ERROR: No trimmed output file found"
            ls -la
            exit 1
        fi

        echo "Trimming complete for ${sample_id}."
        """
    }
}

process run_multiqc {
    tag "MultiQC Report"
    label 'process_low'
    publishDir "${params.outdir}/qc", mode: 'copy'
    container 'multiqc/multiqc:latest' // Using the multiqc container

    // Resource requirements
    cpus 2
    memory { 4.GB }
    time { 20.min }

    input:
    path ('fastqc/*')
    path ('trim_logs/*')
    path ('vast_dirs/*'), stageAs: 'vast_*'

    output:
    path "multiqc_report.html", emit: report
    path "multiqc_report_data"

    script:
    def config_arg = params.multiqc_config ? "--config ${params.multiqc_config}" : ''
    """
    echo "Generating MultiQC report..."
    # Make sure the directory structure is preserved for MultiQC to recognize file types
    mkdir -p trim_galore_reports
    mkdir -p vast_out

    # Move files to appropriate directories based on naming patterns, but avoid moving files to themselves
    find . -name "*trimming_report.txt" -not -path "./trim_galore_reports/*" -exec mv {} ./trim_galore_reports/ \\;
    find . -name "*.tab" -o -name "*.log" | grep -v trimming | grep -v "./vast_out/" | xargs -I{} mv {} ./vast_out/ 2>/dev/null || true

    multiqc . ${config_arg} -f -n multiqc_report.html
    echo "MultiQC report generated."
    """
}

process prepare_vastdb {
    tag "Validate VASTDB"

    // Resource requirements
    cpus 1
    memory { 1.GB }
    time { 5.min }

    input:
    val vastdb_path

    output:
    val vastdb_path, emit: vastdb_path

    script:
    def species_dir = getVastdbDirName(params.species)
    """
    echo "Validating VASTDB structure at ${vastdb_path}"
    echo "Using species directory: ${species_dir} for ${params.species}"

    # Verify the VASTDB path exists
    if [ ! -d "${vastdb_path}" ]; then
        echo "ERROR: VASTDB directory ${vastdb_path} does not exist!"
        exit 1
    fi

    # Check if the species directory exists in VASTDB
    if [ ! -d "${vastdb_path}/${species_dir}" ]; then
        echo "ERROR: Species directory ${species_dir} not found in VASTDB ${vastdb_path}"
        echo "Available directories in VASTDB:"
        ls -la ${vastdb_path}/
        exit 1
    fi

    # Verify key files and directories exist
    echo "Verifying VASTDB structure..."
    ls -la ${vastdb_path}/${species_dir}/ || {
        echo "ERROR: Cannot list contents of species directory"
        exit 1
    }

    echo "VASTDB structure validated successfully"
    """
}

process align_reads {
    tag "VAST-tools alignment: ${sample_id}"
    label 'process_high'
    publishDir "${params.outdir}/vast_alignment", mode: 'copy', pattern: "vast_out/**"
    container 'andresgordoortiz/vast-tools:latest'

    // Retry configuration - retry once if the process fails
    maxRetries 2
    errorStrategy { task.attempt <= maxRetries ? 'retry' : 'terminate' }

    // Resource requirements
    cpus 8
    memory { 50.GB }
    time { 3.hours }

    input:
    tuple val(sample_id), val(sample_type), path(fastq_files), val(group)
    val vastdb_path

    output:
    tuple val(sample_id), val(group), path("vast_out"), emit: alignment_output
    path "vast_out", emit: vast_out_dir

    script:
    def vast_options = "--IR_version 2 -c ${task.cpus} -n ${sample_id} -sp ${params.species} --verbose"

    if (sample_type == 'paired') {
        // Paired-end alignment
        """
        echo "VAST-tools alignment attempt ${task.attempt} for paired-end sample ${sample_id}..."
        mkdir -p vast_out/to_combine
        echo "Starting VAST-tools alignment for paired-end sample ${sample_id}..."
        echo "Using VASTDB path: ${vastdb_path}"

        # Debug info
        echo "Container environment:"
        env | grep SINGULARITY || true

        # Ensure VASTDB is correctly set, with multiple fallback options
        export VASTDB=/usr/local/vast-tools/VASTDB
        echo "VASTDB set to \$VASTDB"

        # Multiple command options for robustness
        if vast-tools align ${fastq_files[0]} ${fastq_files[1]} -o vast_out ${vast_options}; then
            echo "VAST-tools alignment completed successfully"
        else
            echo "First attempt failed, trying with explicit VASTDB path..."
            export VASTDB=${vastdb_path}
            echo "VASTDB now set to \$VASTDB"

            if vast-tools align ${fastq_files[0]} ${fastq_files[1]} -o vast_out ${vast_options}; then
                echo "VAST-tools alignment completed successfully with explicit path"
            else
                echo "Both alignment attempts failed - debugging information:"
                echo "Container filesystem:"
                ls -la /usr/local/vast-tools/ || true
                echo "VASTDB location:"
                ls -la \$VASTDB || true
                vast-tools --version || true
                exit 1
            fi
        fi

        # Verify alignment outputs and debug
        echo "Checking alignment outputs..."
        find vast_out -type f | sort | head -20
        echo "Directory structure:"
        find vast_out -type d | sort

        # Ensure all necessary files are in to_combine directory
        echo "Ensuring all necessary files are in to_combine directory..."
        mkdir -p vast_out/to_combine

        # Find all the different file types VAST-tools creates
        find vast_out -type f -name "*.eej*" -o -name "*.exskX" -o -name "*.info" -o -name "*.IR*" -o -name "*.mic*" -o -name "*.MULTI*" -o -name "*.tab" | while read file; do
            echo "Found file: \$file"
            cp "\$file" vast_out/to_combine/ || echo "Failed to copy \$file"
        done

        # Also look for files directly in cRPKM, to_combine and other subdirectories
        for subdir in vast_out/*/; do
            if [ -d "\$subdir" ] && [ "\$subdir" != "vast_out/to_combine/" ]; then
                echo "Checking subdirectory: \$subdir"
                find "\$subdir" -maxdepth 1 -type f | while read file; do
                    echo "Found file in subdir: \$file"
                    cp "\$file" vast_out/to_combine/ || echo "Failed to copy \$file"
                done
            fi
        done

        # List to_combine contents for verification
        echo "Contents of to_combine directory:"
        ls -la vast_out/to_combine/
        echo "File count in to_combine: \$(find vast_out/to_combine/ -type f | wc -l)"

        echo "VAST-tools alignment complete for ${sample_id}"
        """
    } else {
        // Single-end alignment - same changes as paired-end
        """
        echo "VAST-tools alignment attempt ${task.attempt} for single-end sample ${sample_id}..."
        mkdir -p vast_out/to_combine
        echo "Starting VAST-tools alignment for single-end sample ${sample_id}..."
        echo "Using VASTDB path: ${vastdb_path}"

        # Debug info
        echo "Container environment:"
        env | grep SINGULARITY || true

        # Ensure VASTDB is correctly set, with multiple fallback options
        export VASTDB=/usr/local/vast-tools/VASTDB
        echo "VASTDB set to \$VASTDB"

        # Multiple command options for robustness
        if vast-tools align ${fastq_files} -o vast_out ${vast_options}; then
            echo "VAST-tools alignment completed successfully"
        else
            echo "First attempt failed, trying with explicit VASTDB path..."
            export VASTDB=${vastdb_path}
            echo "VASTDB now set to \$VASTDB"

            if vast-tools align ${fastq_files} -o vast_out ${vast_options}; then
                echo "VAST-tools alignment completed successfully with explicit path"
            else
                echo "Both alignment attempts failed - debugging information:"
                echo "Container filesystem:"
                ls -la /usr/local/vast-tools/ || true
                echo "VASTDB location:"
                ls -la \$VASTDB || true
                vast-tools --version || true
                exit 1
            fi
        fi

        # Verify alignment outputs and debug
        echo "Checking alignment outputs..."
        find vast_out -type f | sort | head -20
        echo "Directory structure:"
        find vast_out -type d | sort

        # Ensure all necessary files are in to_combine directory
        echo "Ensuring all necessary files are in to_combine directory..."
        mkdir -p vast_out/to_combine

        # Find all the different file types VAST-tools creates
        find vast_out -type f -name "*.eej*" -o -name "*.exskX" -o -name "*.info" -o -name "*.IR*" -o -name "*.mic*" -o -name "*.MULTI*" -o -name "*.tab" | while read file; do
            echo "Found file: \$file"
            cp "\$file" vast_out/to_combine/ || echo "Failed to copy \$file"
        done

        # Also look for files directly in cRPKM, to_combine and other subdirectories
        for subdir in vast_out/*/; do
            if [ -d "\$subdir" ] && [ "\$subdir" != "vast_out/to_combine/" ]; then
                echo "Checking subdirectory: \$subdir"
                find "\$subdir" -maxdepth 1 -type f | while read file; do
                    echo "Found file in subdir: \$file"
                    cp "\$file" vast_out/to_combine/ || echo "Failed to copy \$file"
                done
            fi
        done

        # List to_combine contents for verification
        echo "Contents of to_combine directory:"
        ls -la vast_out/to_combine/
        echo "File count in to_combine: \$(find vast_out/to_combine/ -type f | wc -l)"

        echo "VAST-tools alignment complete for ${sample_id}"
        """
    }
}

process combine_results {
    tag "VAST-tools combine"
    label 'process_medium'
    publishDir "${params.outdir}/inclusion_tables", mode: 'copy', pattern: '*INCLUSION_LEVELS_FULL*.tab'
    container 'andresgordoortiz/vast-tools:latest'

    // Retry configuration for segmentation faults
    maxRetries 1  // Reduce retries since it's consistently failing
    errorStrategy { task.exitStatus == 140 ? 'ignore' : 'terminate' }  // Continue pipeline even if combine fails

    // Resource requirements
    cpus 8
    memory { 90.GB }  // Use fixed memory allocation
    time { 1.hour }

    input:
    path vast_out_dirs, stageAs: "vast_*"
    val vastdb_path
    val output_name

    output:
    path "${output_name}_INCLUSION_LEVELS_FULL-${params.species}.tab", emit: inclusion_table

    script:
    """
    echo "VAST-tools combine attempt ${task.attempt} with ${task.memory} memory"
    echo "Using VASTDB path: ${vastdb_path}"

    # Create a clean working directory
    mkdir -p vast_combine_work/to_combine
    cd vast_combine_work

    # Find and copy all valid VAST-tools output files, avoiding duplicates
    echo "Collecting VAST-tools output files from to_combine directories..."

    # Debug: List what directories we have
    echo "Available vast_* directories:"
    ls -la ../vast_* || true

    # Look specifically in the to_combine subdirectories
    for dir in ../vast_*; do
        echo "Processing directory: \$dir"
        if [ -d "\$dir" ]; then
            # Check if to_combine subdirectory exists
            if [ -d "\$dir/to_combine" ]; then
                echo "Found to_combine subdirectory in \$dir"
                ls -la "\$dir/to_combine/" || true

                # Copy files from the to_combine subdirectory
                find "\$dir/to_combine" -type f \\( -name "*.eej2" -o -name "*.exskX" -o -name "*.info" -o -name "*.IR2" -o -name "*.IR.summary_v2.txt" -o -name "*.micX" -o -name "*.MULTI3X" \\) | while read file; do
                    filename=\$(basename "\$file")
                    # Only copy if the file doesn't already exist in our to_combine directory
                    if [ ! -f "to_combine/\$filename" ]; then
                        echo "Copying: \$file -> to_combine/\$filename"
                        cp "\$file" "to_combine/\$filename" || echo "Failed to copy \$file"
                    else
                        echo "Skipping duplicate: \$filename"
                    fi
                done
            else
                echo "WARNING: No to_combine subdirectory found in \$dir"
                echo "Contents of \$dir:"
                ls -la "\$dir" || true

                # Fallback: look for files directly in the vast_out directory
                find "\$dir" -maxdepth 1 -type f \\( -name "*.eej2" -o -name "*.exskX" -o -name "*.info" -o -name "*.IR2" -o -name "*.IR.summary_v2.txt" -o -name "*.micX" -o -name "*.MULTI3X" \\) | while read file; do
                    filename=\$(basename "\$file")
                    if [ ! -f "to_combine/\$filename" ]; then
                        echo "Copying from root: \$file -> to_combine/\$filename"
                        cp "\$file" "to_combine/\$filename" || echo "Failed to copy \$file"
                    else
                        echo "Skipping duplicate: \$filename"
                    fi
                done
            fi
        else
            echo "WARNING: \$dir is not a directory or doesn't exist"
        fi
    done

    # Count files to combine
    file_count=\$(find to_combine -type f | wc -l)
    echo "Found \$file_count unique files to combine."

    if [ \$file_count -gt 0 ]; then
        echo "Files to be combined:"
        ls -la to_combine/
        echo "Total size: \$(du -sh to_combine/)"

        # Set up VAST-tools environment
        export VASTDB=/usr/local/vast-tools/VASTDB
        echo "VASTDB set to \$VASTDB"

        # Try running VAST-tools combine with different approaches
        echo "Attempting VAST-tools combine..."

        # First attempt: Standard combine
        if timeout 30m vast-tools combine to_combine/ -sp ${params.species} -o . --verbose; then
            echo "VAST-tools combine completed successfully"
        else
            combine_exit_code=\$?
            echo "First combine attempt failed (exit code: \$combine_exit_code)"

            # Second attempt: Try with explicit VASTDB
            export VASTDB=${vastdb_path}
            echo "Trying with explicit VASTDB: \$VASTDB"

            if timeout 30m vast-tools combine to_combine/ -sp ${params.species} -o . --verbose; then
                echo "VAST-tools combine completed with explicit VASTDB"
            else
                second_exit_code=\$?
                echo "Second combine attempt also failed (exit code: \$second_exit_code)"

                # Create a minimal placeholder file if combine fails
                echo "Creating placeholder inclusion table due to combine failure..."
                echo "# VAST-tools combine failed with segmentation fault" > "../${output_name}_INCLUSION_LEVELS_FULL-${params.species}.tab"
                echo "# Files were present but combine process crashed" >> "../${output_name}_INCLUSION_LEVELS_FULL-${params.species}.tab"
                echo "# Input files (\$file_count total):" >> "../${output_name}_INCLUSION_LEVELS_FULL-${params.species}.tab"
                ls to_combine/ | head -10 | sed 's/^/# /' >> "../${output_name}_INCLUSION_LEVELS_FULL-${params.species}.tab"
                echo "# Created on: \$(date)" >> "../${output_name}_INCLUSION_LEVELS_FULL-${params.species}.tab"

                # Exit with the original error code if this is not the final retry
                if [ ${task.attempt} -lt ${task.maxRetries} ]; then
                    exit \$second_exit_code
                else
                    echo "Max retries reached, continuing with placeholder file"
                    exit 0  # Allow pipeline to continue
                fi
            fi
        fi

        # Look for generated inclusion table
        echo "Looking for generated inclusion table..."
        ls -la .

        inclusion_file=\$(find . -name "INCLUSION_LEVELS_FULL*${params.species}*" -type f | head -n 1)
        if [ -n "\$inclusion_file" ]; then
            echo "Found inclusion file: \$inclusion_file"
            file_size=\$(stat -c%s "\$inclusion_file")
            echo "File size: \$file_size bytes"

            if [ \$file_size -gt 100 ]; then
                cp "\$inclusion_file" "../${output_name}_INCLUSION_LEVELS_FULL-${params.species}.tab"
                echo "✓ Results successfully combined and inclusion table created"
            else
                echo "WARNING: Generated inclusion file is too small"
                echo "# WARNING: Generated file was too small (\$file_size bytes)" > "../${output_name}_INCLUSION_LEVELS_FULL-${params.species}.tab"
                echo "# Created on: \$(date)" >> "../${output_name}_INCLUSION_LEVELS_FULL-${params.species}.tab"
            fi
        else
            echo "WARNING: No inclusion table file found after combine"
            echo "Available files:"
            find . -type f | head -20
            echo "# WARNING: VAST-tools combine completed but no inclusion table found" > "../${output_name}_INCLUSION_LEVELS_FULL-${params.species}.tab"
            echo "# Created on: \$(date)" >> "../${output_name}_INCLUSION_LEVELS_FULL-${params.species}.tab"
        fi
    else
        echo "ERROR: No valid VAST-tools files found to combine"
        cd ..
        echo "# ERROR: No valid VAST-tools output files found" > "${output_name}_INCLUSION_LEVELS_FULL-${params.species}.tab"
        echo "# Searched in directories and their to_combine subdirectories:" >> "${output_name}_INCLUSION_LEVELS_FULL-${params.species}.tab"
        for dir in vast_*; do
            echo "# Directory: \$dir" >> "${output_name}_INCLUSION_LEVELS_FULL-${params.species}.tab"
            if [ -d "\$dir/to_combine" ]; then
                echo "#   to_combine/ exists with \$(find \$dir/to_combine -type f | wc -l) files" >> "${output_name}_INCLUSION_LEVELS_FULL-${params.species}.tab"
                find "\$dir/to_combine" -type f | head -5 | sed 's/^/#     /' >> "${output_name}_INCLUSION_LEVELS_FULL-${params.species}.tab"
            else
                echo "#   to_combine/ subdirectory not found" >> "${output_name}_INCLUSION_LEVELS_FULL-${params.species}.tab"
                echo "#   Contents: \$(ls \$dir 2>/dev/null | wc -l) items" >> "${output_name}_INCLUSION_LEVELS_FULL-${params.species}.tab"
            fi
        done
        echo "# Created on: \$(date)" >> "${output_name}_INCLUSION_LEVELS_FULL-${params.species}.tab"
    fi
    """
}

process run_rmarkdown_report {
    tag "Generate R analysis report"
    label 'process_high'
    publishDir "${params.outdir}/report", mode: 'copy', pattern: '*.html'
    container 'andresgordoortiz/splicing_analysis_r_crg:v1.5' // Using biocontainer for R with rmarkdown

    // Resource requirements - as per your specifications
    cpus 2
    memory { 30.GB }
    time { 72.hours } // 3 days

    input:
    path inclusion_table
    val rmd_file

    output:
    path "*.html", optional: true, emit: report_html

    when:
    !params.skip_rmarkdown

    script:
    def rmd_basename = file(rmd_file).name
    def html_basename = rmd_basename.replace('.Rmd', '.html')

    """
    # Create notebooks directory
    mkdir -p notebooks

    # Copy inclusion table to notebooks directory
    cp ${inclusion_table} notebooks/

    # Verify the RMarkdown file exists
    RMD_FILE="${rmd_file}"
    if [ ! -f "\$RMD_FILE" ]; then
        echo "ERROR: RMarkdown file \$RMD_FILE not found. Cannot generate the report."
        exit 1
    fi

    # Copy the Rmd file to the notebooks directory
    cp "\$RMD_FILE" notebooks/

    # Run the RMarkdown report
    cd notebooks
    Rscript -e "rmarkdown::render('${rmd_basename}')"

    # Move the HTML report from notebooks to current directory
    cp "${html_basename}" ../

    echo "✓ R Markdown report generated: ${html_basename}"
    """
}

// Function to get VASTDB directory from species code
def getVastdbDirName(species) {
    // Map species names to VASTDB folder names
    def speciesDirectoryMap = [
        'hg19': 'Hsa',
        'hg38': 'Hs2',
        'mm9': 'Mmu',
        'mm10': 'Mm2',
        'rn6': 'Rno',
        'bosTau6': 'Bta',
        'galGal3': 'Gg3',
        'galGal4': 'Gg4',
        'xenTro3': 'Xt1',
        'danRer10': 'Dre',
        'braLan2': 'Bl1',
        'strPur4': 'Spu',
        'dm6': 'Dme',
        'strMar1': 'Sma',
        'ce11': 'Cel',
        'schMed31': 'Sme',
        'nemVec1': 'Nve',
        'araTha10': 'Ath'
    ]

    return speciesDirectoryMap.containsKey(species) ?
           speciesDirectoryMap[species] :
           species
}

// Define a function to parse the sample CSV and create channels
def parseSamplesCsv(sampleCsv) {
    Channel.fromPath(sampleCsv)
        .splitCsv(header: true, strip: true)
        .map { row ->
            // Check if the required fields are present
            if (row.sample == null || row.fastq_1 == null || row.type == null) {
                log.error "ERROR: Missing required fields in sample CSV. Each row must have 'sample', 'fastq_1', and 'type'."
                exit 1
            }

            // Check if the type is valid (single, paired, technical_replicate)
            if (!['single', 'paired', 'technical_replicate'].contains(row.type.toLowerCase())) {
                log.error "ERROR: Invalid value for 'type' in sample CSV. Must be 'single', 'paired', or 'technical_replicate'."
                exit 1
            }

            def sampleId = row.sample

            // FIX: Handle relative paths by prepending the data directory if needed
            def fastq1Path = row.fastq_1
            if (!fastq1Path.startsWith("/") && !fastq1Path.startsWith("./") && !fastq1Path.startsWith("../")) {
                fastq1Path = "${params.data_dir}/${fastq1Path}"
            }
            def fastq1 = file(fastq1Path, checkIfExists: true)

            // For paired-end reads, check if fastq_2 is provided
            def fastq2 = null
            if (row.fastq_2) {
                def fastq2Path = row.fastq_2
                if (!fastq2Path.startsWith("/") && !fastq2Path.startsWith("./") && !fastq2Path.startsWith("../")) {
                    fastq2Path = "${params.data_dir}/${fastq2Path}"
                }
                fastq2 = file(fastq2Path, checkIfExists: true)
            }

            if (row.type.toLowerCase() == 'paired' && fastq2 == null) {
                log.error "ERROR: Type is set to 'paired' for sample '${sampleId}' but 'fastq_2' is missing."
                exit 1
            }

            // For technical replicates, get all fastq files
            def fastq_files = []
            if (row.type.toLowerCase() == 'technical_replicate') {
                fastq_files.add(fastq1)
                if (fastq2) fastq_files.add(fastq2)

                // Check for additional technical replicates (handle relative paths)
                def additionalFastqs = (3..10).collect { i ->
                    def key = "fastq_${i}"
                    if (row.containsKey(key) && row[key]) {
                        def fastqPath = row[key]
                        if (!fastqPath.startsWith("/") && !fastqPath.startsWith("./") && !fastqPath.startsWith("../")) {
                            fastqPath = "${params.data_dir}/${fastqPath}"
                        }
                        return file(fastqPath, checkIfExists: true)
                    }
                    return null
                }
                additionalFastqs.removeAll([null])
                fastq_files.addAll(additionalFastqs)
            } else if (row.type.toLowerCase() == 'paired') {
                fastq_files = [fastq1, fastq2]
            } else {
                fastq_files = [fastq1]
            }

            // Return a tuple with sample info
            return [sampleId, row.type.toLowerCase(), fastq_files, row.group ?: sampleId]
        }
}

// Define the workflow
workflow {
    // Show help message if help flag is specified
    if (params.help) {
        helpMessage()
        exit 0
    }

    // Validate parameters first
    validateParameters()

    // Execute processes in order with proper logging
    log.info """
    Starting pipeline with parameters:
      - Sample CSV:        ${params.sample_csv}
      - VASTDB path:       ${params.vastdb_path}
      - Data directory:    ${params.data_dir} (MANDATORY)
      - Output directory:  ${params.outdir}
      - Species:           ${params.species}
      - Skip FastQC:       ${params.skip_fastqc}
      - Skip Trimming:     ${params.skip_trimming}
      - Skip FastQC in Trimming: ${params.skip_fastqc_in_trimming}
      - Skip RMarkdown:    ${params.skip_rmarkdown}
    """

    // Prepare VASTDB - now just validates paths
    vastdb_path = prepare_vastdb(params.vastdb_path)

    // Parse sample CSV and create sample channels
    sample_channel = parseSamplesCsv(params.sample_csv)

    // Split samples by type to process differently
    tech_rep_samples = sample_channel.filter { it[1] == 'technical_replicate' }
    paired_samples = sample_channel.filter { it[1] == 'paired' }
    single_samples = sample_channel.filter { it[1] == 'single' }

    // Process samples according to their type
    concatenated_tech_rep = concatenate_technical_replicates(tech_rep_samples)
    prepared_paired = prepare_paired_reads(paired_samples)
    prepared_single = prepare_single_reads(single_samples)

    // Combine all prepared samples
    all_prepared_samples = concatenated_tech_rep
        .mix(prepared_paired)
        .mix(prepared_single)

    // Process flow depends on whether trimming is enabled
    // If trimming is enabled, trim_galore can run FastQC automatically
    // If trimming is disabled, we might run standalone FastQC

    if (!params.skip_trimming) {
        // Run trim_galore on all samples
        trimmed_results = run_trim_galore(all_prepared_samples)

        // Use the trimmed reads for downstream processes
        samples_for_alignment = trimmed_results.trimmed_reads

        // Get FastQC results from trim_galore if fastqc in trimming isn't skipped
        fastqc_results = params.skip_fastqc_in_trimming ?
            Channel.empty() :
            trimmed_results.fastqc_results
    } else {
        // Skip trimming - use the raw reads
        samples_for_alignment = all_prepared_samples

        // Only run standalone FastQC if trimming is skipped (to avoid duplicate FastQC runs)
        fastqc_results = params.skip_fastqc ? Channel.empty() : run_fastqc(all_prepared_samples)
    }

    // Align all samples with VAST-tools
    align_results = align_reads(samples_for_alignment, vastdb_path)

    // Use the named output channels directly
    vast_out_dirs = align_results.vast_out_dir.collect()

    // Get a unique name for the output based on the project name or custom parameter
    output_name = "splicing_analysis"

    // Combine all alignment results
    inclusion_table = combine_results(vast_out_dirs, vastdb_path, output_name)

    // Run MultiQC if FastQC was run (either standalone or via trim_galore)
    if ((!params.skip_trimming && !params.skip_fastqc_in_trimming) || (params.skip_trimming && !params.skip_fastqc)) {
        // Use the named output channel directly - no need to map again
        vast_dirs_for_multiqc = align_results.vast_out_dir.collect()

        // Handle optional channels properly
        trim_logs = params.skip_trimming ?
            Channel.empty() :
            run_trim_galore.out.trim_log.collect()

        fastqc_for_multiqc = fastqc_results.collect()

        // Run MultiQC with properly separated inputs
        multiqc_report = run_multiqc(
            fastqc_for_multiqc,
            trim_logs,
            vast_dirs_for_multiqc
        )
    }

    // Run the RMarkdown report if not skipped
    if (!params.skip_rmarkdown) {
        // Use the params.rmd_file directly since we validated it exists
        report = run_rmarkdown_report(inclusion_table, params.rmd_file)
    } else {
        log.info "Skipping RMarkdown report as per user request or missing RMarkdown file."
    }

    log.info """
    ======================================
     Pipeline Execution Complete
    ======================================

    Results are available in: ${params.outdir}
    """
}