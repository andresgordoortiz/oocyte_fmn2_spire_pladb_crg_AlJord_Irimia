#!/bin/bash
# Run it with bash run_analysis.sh /path/to/data

# Define variables for data directory and group selection
DATA_PATH=${5:-/usr/local/vast-tools/share}  # Default to /usr/local/vast-tools/share within the container
DOCKER_IMAGE="vast-tools"

# Run Docker container with mounted data directory
# Run Docker container with specified volumes and run the analysis within the container
docker run --rm \
    -v $(pwd)/tests/data_tests/:/usr/local/vast-tools/share \
    -v $(pwd)/VASTDB:/usr/local/vast-tools/VASTDB \
    vast-tools bash -c "
    # Move to the data directory
    cd $DATA_PATH


    # Generate temporary files for each data group
    matt add_val AS_NC--dPSI25-range5-min_ALT_use25-upreg_ALT_Control-vs-Spire_DKO-with_dPSI-Max_dPSI5.tab GROUP AS_NC | grep -P '(MmuEX|EVENT)' | matt rand_rows - 1000 > AS_NC_tmp.tab
    matt add_val CR--dPSI25-range5-min_ALT_use25-upreg_ALT_Control-vs-Spire_DKO-with_dPSI.tab GROUP CR | grep -P '(MmuEX|EVENT)' | matt rand_rows - 1000 > CR_tmp.tab
    matt add_val CS--dPSI25-range5-min_ALT_use25-upreg_ALT_Control-vs-Spire_DKO-with_dPSI.tab GROUP CS | grep -P '(MmuEX|EVENT)' | matt rand_rows - 1000 > CS_tmp.tab
    matt get_rows DiffAS--dPSI25-range5-min_ALT_use25-upreg_ALT_Control-vs-Spire_DKO-with_dPSI.tab dPSI[15,100] | matt add_val - GROUP Spire_Up | grep -P '(MmuEX|EVENT)' > up_tmp.tab

    # Merge all temporary tables
    matt add_rows AS_NC_tmp.tab CR_tmp.tab
    matt add_rows AS_NC_tmp.tab CS_tmp.tab
    matt add_rows AS_NC_tmp.tab up_tmp.tab

    # Copy merged results to a new file
    cp AS_NC_tmp.tab merged.tab
    rm *_tmp.tab

    # Download necessary genome annotation files if not present
    [ ! -f mm10.gtf ] && wget -O - https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_mouse/release_M10/gencode.vM10.annotation.gtf.gz | gunzip > mm10.gtf
    [ ! -f mm10.fasta ] && wget -O - https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_mouse/release_M10/GRCm38.primary_assembly.genome.fa.gz | gunzip > mm10.fasta

    # Prepare input for the 'matt' tool
    matt get_vast merged.tab COORD FullCO COMPLEX LENGTH -gtf mm10.gtf > matt_input_ex.tab


    # Compare exons
    matt cmpr_exons matt_input_ex.tab START END SCAFFOLD STRAND GENEID mm10.gtf mm10.fasta Mmus 150 GROUP[Spire_Up,CR,AS_NC,CS] Matt_Out -notrbts -colors:red,white,lightgray,darkgray

    # Create UGC motif configuration and run RNA maps
    echo -e 'TYPE\tNAME\tEXPR_FILE\tTHRESH\tBGMODEL\tREGEXP\tUGC\tTGC\tNA\tNA' > ugc_motif.tab
    matt rna_maps matt_input_ex.tab UPSTRM_EX_BORDER START END DOSTRM_EX_BORDER SCAFFOLD STRAND GROUP 15 50 150 mm10.fasta ugc_motif.tab TYPE NAME EXPR_FILE THRESH BGMODEL REGEXP -d UGC_map_Matt
"

echo "Analysis completed successfully."
