nextflow.enable.dsl=2

process download_reads {
    tag "$task.name"
    memory '5 GB'
    time '3 min'

    output:
    path "data/raw/fmndko", emit: raw_dir

    script:
    """
    mkdir -p data/raw/fmndko
    cd data/raw/fmndko
    sed "\$((task.index + 1))q;d" fmndko_PRJNA406820.sh | bash
    """
}

process concatenate_reads {
    tag "$task.name"
    memory '4 GB'
    time '30 min'

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
    memory '5 GB'
    time '60 min'
    container 'docker://biocontainers/fastqc:v0.11.9_cv8'

    input:
    path processed_dir

    output:
    path "data/processed/fmndko/fastqc", emit: fastqc_dir

    script:
    """
    mkdir -p data/processed/fmndko/fastqc
    fastqc -t 8 -o data/processed/fmndko/fastqc data/processed/fmndko/*.{fastq.gz,fq.gz}
    """
}

process align_reads {
    tag "$task.name"
    memory '10 GB'
    time '120 min'
    container 'docker://andresgordoortiz/vast-tools:latest'

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
        singularity exec --bind ${vastdb_path}:/usr/local/vast-tools/VASTDB \
            --bind data/processed/fmndko/vast_out:/vast_out \
            docker://andresgordoortiz/vast-tools:latest vast-tools align \
            "\$file" -sp mm10 -o /vast_out --IR_version 2 -c 8 -n "\$basename"
    done
    """
}

process combine_results {
    tag "$task.name"
    memory '5 GB'
    time '20 min'
    container 'docker://andresgordoortiz/vast-tools:latest'

    input:
    path vast_out_dir
    val vastdb_path

    script:
    """
    singularity exec --bind ${vastdb_path}:/usr/local/vast-tools/VASTDB \
        --bind \$PWD/data/processed/fmndko:/fmndko \
        docker://andresgordoortiz/vast-tools:latest bash -c "vast-tools combine /fmndko/vast_out/to_combine -sp mm10 -o /fmndko/vast_out"
    mkdir -p \$PWD/notebooks/inclusion_tables/
    mv \$PWD/data/processed/fmndko/vast_out/INCLUSION_LEVELS_FULL* \$PWD/notebooks/inclusion_tables/fmndko_INCLUSION_LEVELS_FULL-mm10.tab
    """
}

// Define workflow with proper dependencies
workflow {
    // Define parameter for VAST-DB path
    params.vastdb_path = "/path/to/vastdb"

    // Execute processes in order
    raw_dir = download_reads()
    processed_dir = concatenate_reads(raw_dir)

    // Run FastQC and alignment in parallel after concatenation
    fastqc_dir = run_fastqc(processed_dir)
    vast_out_dir = align_reads(processed_dir, params.vastdb_path)

    // Combine results after alignment
    combine_results(vast_out_dir, params.vastdb_path)
}