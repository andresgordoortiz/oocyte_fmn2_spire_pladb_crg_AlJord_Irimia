#!/usr/bin/env nextflow

/*
==========================================
 FMN2/Spire Alternative Splicing Analysis Pipeline
==========================================
 Authors: Andrés Gordo
 Date: April 2025

 This pipeline processes RNA-Seq data for analyzing
 alternative splicing patterns in FMN2/Spire knockouts
 using VAST-tools.
*/

nextflow.enable.dsl=2

// Default parameters
params.outdir = "results"
params.vastdb_path = "/path/to/vastdb"
params.script_file = "$projectDir/data/raw/fmndko/fmndko_PRJNA406820.sh"
params.help = false


process download_reads {
    tag "Downloading raw sequencing data"
    label 'network'
    publishDir "${params.outdir}/raw", mode: 'copy', pattern: 'fastq_files'

    output:
    path "fastq_files", emit: raw_dir

    script:
    """
    mkdir -p fastq_files

    echo "Starting download of raw sequencing data..."

    # Process all lines in the script
    step=1
    cat ${params.script_file} | while read line; do
        if [[ \$line != "#"* ]] && [[ ! -z "\$line" ]]; then
            echo "Step \$step: Executing download command: \$line"
            \$line || { echo "Download command failed: \$line"; exit 1; }
            echo "Step \$step complete."
            step=\$((step + 1))
        fi
    done

    # Move all downloaded files to output directory
    find . -name "*.fastq.gz" -exec mv {} fastq_files/ \\;

    echo "Download complete. \$(ls -1 fastq_files | wc -l) files downloaded."
    """
}

process concatenate_reads {
    tag "Merging technical replicates"
    label 'process_medium'
    publishDir "${params.outdir}/processed", mode: 'copy', pattern: 'processed'

    input:
    path raw_dir

    output:
    path "processed", emit: processed_dir

    script:
    """
    mkdir -p processed
    echo "Starting read concatenation process..."

    # List files in input directory
    files=(\$(find ${raw_dir} -name "*.fastq.gz" | sort))
    echo "Found \${#files[@]} files for processing"

    # Group and concatenate files in sets of 3
    for ((i=0; i<\${#files[@]}; i+=3)); do
        if [[ \$i+2 < \${#files[@]} ]]; then
            file1=\${files[i]}
            file2=\${files[i+1]}
            file3=\${files[i+2]}
            basename1=\$(basename \$file1 .fastq.gz | cut -d'_' -f1)

            output_file="processed/\${basename1}_merged.fastq.gz"
            echo "Merging replicate set \$((i/3+1)) to \$output_file"
            cat "\$file1" "\$file2" "\$file3" > "\$output_file"
            echo "✓ Merged \$(basename \$file1), \$(basename \$file2), and \$(basename \$file3)"
        fi
    done

    echo "Concatenation complete. \$(ls -1 processed | wc -l) merged files created."
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
        vast-tools align "\$file" -sp mm10 -o vast_out --IR_version 2 -c ${task.cpus} -n "\$basename" || { echo "Alignment failed for \$basename"; exit 1; }
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
    path "fmndko_INCLUSION_LEVELS_FULL-mm10.tab", optional: true

    script:
    """
    echo "Combining VAST-tools results..."
    vast-tools combine ${vast_out_dir}/to_combine -sp mm10 -o ${vast_out_dir} || { echo "VAST-tools combine failed"; exit 1; }

    # Move inclusion tables to output
    if [ -f ${vast_out_dir}/INCLUSION_LEVELS_FULL* ]; then
        cp ${vast_out_dir}/INCLUSION_LEVELS_FULL* fmndko_INCLUSION_LEVELS_FULL-mm10.tab
        echo "✓ Results successfully combined and inclusion table created"
    else
        echo "WARNING: No INCLUSION_LEVELS_FULL file was created"
        exit 1
    fi
    """
}


// Define workflow with proper dependencies
workflow {
    // Check required parameters
    if (params.vastdb_path == "/path/to/vastdb") {
        error "Please set the params.vastdb_path parameter to the location of your VAST-DB directory"
    }

    // Get the download script
    download_script = file(params.script_file)
    if (!download_script.exists()) {
        error "Download script ${params.script_file} not found"
    }

    // Execute processes in order with proper logging
    println "Starting pipeline execution..."

    // Use process outputs instead of direct log.info statements
    download_reads()
    .tap { println "Step 1/5: Downloading raw data..." }
    .set { raw_dir }

    concatenate_reads(raw_dir)
    .tap { println "Step 2/5: Concatenating technical replicates..." }
    .set { processed_dir }

    // Run FastQC on processed reads
    run_fastqc(processed_dir)
    .tap { println "Step 3/5: FastQC quality control complete" }

    // Align reads
    align_reads(processed_dir, params.vastdb_path)
    .tap { println "Step 4/5: VAST-tools alignment complete" }
    .set { vast_out_dir }

    // Combine results after alignment
    combine_results(vast_out_dir, params.vastdb_path)
    .tap { println "Step 5/5: VAST-tools results combined" }

    // Display workflow completion message
    workflow.onComplete {
        println """
        ===========================================
        Pipeline execution summary
        ===========================================
        Completed at : ${workflow.complete}
        Duration     : ${workflow.duration}
        Success      : ${workflow.success}
        Results      : ${params.outdir}
        Work dir     : ${workflow.workDir}
        ===========================================
        """
    }
}