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
params.outdir = "nextflow_results"
params.vastdb_path = "/path/to/vastdb"
params.script_file = "$projectDir/data/raw/fmndko/fmndko_PRJNA406820.sh"
params.help = false
params.rmd_file = "$projectDir/scripts/R/notebooks/Oocyte_fmndko_spireko_complete.Rmd"

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

    # Extract all filenames from the script
    grep -v '^#' ${params.script_file} | grep -v '^\$' | awk -F/ '{print \$NF}' > expected_files.txt
    total_commands=\$(wc -l < expected_files.txt)
    echo "Found \$total_commands files to download"

    # Check if all files already exist in the publish directory
    if [ -d "${params.outdir}/raw/fastq_files" ]; then
        missing_files=0
        while read filename; do
            if [ ! -f "${params.outdir}/raw/fastq_files/\$filename" ]; then
                missing_files=\$((missing_files + 1))
                echo "Missing file: \$filename"
            fi
        done < expected_files.txt

        if [ \$missing_files -eq 0 ]; then
            echo "All \$total_commands files already exist in ${params.outdir}/raw/fastq_files"
            echo "Skipping download step and copying existing files..."
            cp -r "${params.outdir}/raw/fastq_files/"* fastq_files/
            echo "Files copied. Download step skipped."
            exit 0
        else
            echo "\$missing_files files are missing. Proceeding with download..."
        fi
    else
        echo "Destination directory doesn't exist yet. Will download all files."
    fi

    # Process all lines in the script
    step=1
    while read line; do < ${params.script_file}
        if [[ \$line != "#"* ]] && [[ ! -z "\$line" ]]; then
            percentage=\$(( (step * 100) / total_commands ))
            echo "===== File \$step of \$total_commands [\$percentage%] ====="

            # Extract filename from the URL
            filename=\$(echo \$line | awk -F/ '{print \$NF}')
            echo "Downloading: \$filename"

            # Skip if file already exists in the target directory
            if [ -f "${params.outdir}/raw/fastq_files/\$filename" ]; then
                echo "File \$filename already exists in destination. Copying instead of downloading..."
                cp "${params.outdir}/raw/fastq_files/\$filename" fastq_files/
                echo "✓ Copied: \$filename"
            else
                # Use wget with progress bar for each file
                if [[ \$line =~ ^https?:// ]]; then
                    wget "\$line" -q --show-progress || { echo "Download command failed: \$line"; exit 1; }
                else
                if [[ -f "fastq_files/\$filename" ]]; then
                fi

                # Verify file was downloaded
                if [[ -f \$filename ]]; then
                    echo "✓ Downloaded: \$filename"
                    # Move file immediately to fastq_files directory
                    mv \$filename fastq_files/
                    echo "✓ Moved to fastq_files directory"
                else
                    echo "Error: File \$filename not found after download"
                    exit 1
                fi
            fi

            echo "Progress: \$step/\$total_commands files complete [\$percentage%]"
            step=\$((step + 1))
            echo ""
        fi
    done

    # Count number of successfully downloaded files
    file_count=\$(ls -1 fastq_files | wc -l)
    if [ \$file_count -ne \$total_commands ]; then
        echo "Warning: Expected \$total_commands files but found \$file_count in output directory"
    else
        echo "Success: All \$total_commands files downloaded and moved to fastq_files directory"
    fi

    echo "Download complete. \$file_count files downloaded."
    """
}

process concatenate_reads {
    tag "Merging technical replicates"
    label 'process_medium'
    publishDir "${params.outdir}/processed", mode: 'copy'

    input:
    path raw_dir

    output:
    path "*.fastq.gz", emit: processed_dir

    script:
    """
    echo "Starting read concatenation process..."

    # Debug input directory contents
    echo "Contents of input directory '${raw_dir}':"
    ls -la ${raw_dir}/

    # Find all FASTQ files using separate commands
    echo "Finding FASTQ files for processing..."
    find ${raw_dir} -name "*.fastq.gz" > fastq_files.txt
    find ${raw_dir} -name "*.fq.gz" >> fastq_files.txt
    find ${raw_dir} -name "*.fastq" >> fastq_files.txt
    find ${raw_dir} -name "*.fq" >> fastq_files.txt

    file_count=\$(wc -l < fastq_files.txt)
    echo "Found \$file_count FASTQ files for processing"

    # Check if we have any files to process
    if [ \$file_count -eq 0 ]; then
        echo "WARNING: No FASTQ files found in input directory"
        touch empty_placeholder.fastq.gz
    else
        # Sort the files for consistent grouping
        sort fastq_files.txt > sorted_files.txt

        # Simple approach: Process files in groups of 3
        i=1
        while [ \$i -le \$file_count ]; do
            # Get current file and calculate next indices
            file1=\$(sed -n "\${i}p" sorted_files.txt)
            next=\$((i+1))
            nextnext=\$((i+2))

            # Check if we have all 3 files in the group
            if [ \$next -le \$file_count ] && [ \$nextnext -le \$file_count ]; then
                file2=\$(sed -n "\${next}p" sorted_files.txt)
                file3=\$(sed -n "\${nextnext}p" sorted_files.txt)

                # Extract basename for output naming (simpler approach)
                base1=\$(basename \$file1)
                # Remove extensions with simplified pattern matching
                base1=\${base1%.fastq.gz}
                base1=\${base1%.fq.gz}
                base1=\${base1%.fastq}
                base1=\${base1%.fq}

                echo "Merging to \${base1}_merged.fastq.gz: \$(basename \$file1), \$(basename \$file2), \$(basename \$file3)"

                # Build concatenation command based on file extensions
                cmd="("
                for file in "\$file1" "\$file2" "\$file3"; do
                    if [[ \$file == *.gz ]]; then
                        cmd="\$cmd gunzip -c \$file; "
                    else
                        cmd="\$cmd cat \$file; "
                    fi
                done
                cmd="\$cmd) | gzip > \${base1}_merged.fastq.gz"

                # Execute the command
                eval \$cmd
                echo "✓ Merged files into \${base1}_merged.fastq.gz"
            fi

            # Move to next group
            i=\$((i+3))
        done
    fi

    echo "Concatenation complete. \$(ls -1 *.fastq.gz 2>/dev/null | wc -l) merged files created."
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
    path "fmndko_INCLUSION_LEVELS_FULL-mm10.tab", optional: true, emit: inclusion_table

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

    # Download protein impact file if needed
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

    # Run the RMarkdown report
    singularity run --bind "\$(pwd)/notebooks:/shared" \\
      docker://andresgordoortiz/splicing_analysis_r_crg:v1.5 \\
      bash -c "cd /; Rscript -e \\\"rmarkdown::render('/shared/Oocyte_fmndko_spireko_complete.Rmd')\\\""

    # Move the HTML report from notebooks to current directory
    cp notebooks/Oocyte_fmndko_spireko_complete.html ./
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
    log.info "Starting pipeline execution..."

    // Run processes in sequence with proper channel connections
    raw_dir = download_reads()

    processed_dir = concatenate_reads(raw_dir)

    // Run FastQC on processed reads
    run_fastqc(processed_dir)

    // Align reads
    vast_out_dir = align_reads(processed_dir, params.vastdb_path)

    // Combine results after alignment
    inclusion_table = combine_results(vast_out_dir, params.vastdb_path)

    // Run the Rmarkdown report
    run_rmarkdown_report(inclusion_table)
}