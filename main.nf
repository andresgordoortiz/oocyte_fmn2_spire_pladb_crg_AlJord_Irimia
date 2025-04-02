nextflow.enable.dsl=2

params.vastdb_path = "/path/to/vastdb"  // Should be set by user
params.script_file = "fmndko_PRJNA406820.sh"  // Script containing URLs or commands

process download_reads {
    tag "$task.name"

    input:
    path download_script

    output:
    path "data/raw/fmndko", emit: raw_dir

    script:
    """
    mkdir -p data/raw/fmndko
    cd data/raw/fmndko
    sed "\$((task.index + 1))q;d" ${download_script} | bash
    """
}

process concatenate_reads {
    tag "$task.name"

    input:
    path raw_dir

    output:
    path "data/processed/fmndko", emit: processed_dir

    script:
    """
    mkdir -p data/processed/fmndko
    input_dir="data/raw/fmndko"
    output_dir="data/processed/fmndko"
    files=(\$(ls "\$input_dir"/*.fastq.gz))
    for ((i=0; i<\${#files[@]}; i+=3)); do
        output_file="\$output_dir/\$(basename \${files[i]} .fastq.gz)_\$(basename \${files[i+1]} .fastq.gz)_\$(basename \${files[i+2]} .fastq.gz)_merged.fastq.gz"
        cat "\${files[i]}" "\${files[i+1]}" "\${files[i+2]}" > "\$output_file"
        echo "Merged \${files[i]}, \${files[i+1]}, and \${files[i+2]} into \$output_file"
    done
    """
}

process run_fastqc {
    tag "$task.name"

    input:
    path processed_dir

    output:
    path "data/processed/fmndko/fastqc", emit: fastqc_dir

    script:
    """
    mkdir -p data/processed/fmndko/fastqc
    fastqc -t ${task.cpus} -o data/processed/fmndko/fastqc data/processed/fmndko/*.{fastq.gz,fq.gz}
    """
}

process align_reads {
    tag "$task.name"

    input:
    path processed_dir
    val vastdb_path

    output:
    path "data/processed/fmndko/vast_out", emit: vast_out_dir

    script:
    """
    mkdir -p data/processed/fmndko/vast_out

    for file in data/processed/fmndko/*.fastq.gz; do
        basename=\$(basename \$file .fastq.gz)
        vast-tools align "\$file" -sp mm10 -o data/processed/fmndko/vast_out --IR_version 2 -c ${task.cpus} -n "\$basename"
    done
    """
}

process combine_results {
    tag "$task.name"
    publishDir "notebooks/inclusion_tables", mode: 'copy', pattern: '*INCLUSION_LEVELS_FULL*.tab'

    input:
    path vast_out_dir
    val vastdb_path

    output:
    path "fmndko_INCLUSION_LEVELS_FULL-mm10.tab", optional: true

    script:
    """
    vast-tools combine data/processed/fmndko/vast_out/to_combine -sp mm10 -o data/processed/fmndko/vast_out

    # Move inclusion tables to output
    if [ -f data/processed/fmndko/vast_out/INCLUSION_LEVELS_FULL* ]; then
        cp data/processed/fmndko/vast_out/INCLUSION_LEVELS_FULL* fmndko_INCLUSION_LEVELS_FULL-mm10.tab
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

    // Execute processes in order
    raw_dir = download_reads(download_script)
    processed_dir = concatenate_reads(raw_dir)

    // Run FastQC and alignment in parallel after concatenation
    fastqc_dir = run_fastqc(processed_dir)
    vast_out_dir = align_reads(processed_dir, params.vastdb_path)

    // Combine results after alignment
    combine_results(vast_out_dir, params.vastdb_path)
}