#!/bin/bash


##################
# slurm settings #
##################

# where to put stdout / stderr
#SBATCH --output=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.out
#SBATCH --error=/users/aaljord/agordo/git/24CRG_ADEL_MANU_OOCYTE_SPLICING/logs/%x.%A_%a.err

# time limit in minutes
#SBATCH --time=1

# queue
#SBATCH --qos=vshort

# memory (MB)
#SBATCH --mem=500

# job name
#SBATCH --job-name vast-compare

#################
# start message #
#################
start_epoch=`date +%s`
echo [$(date +"%Y-%m-%d %H:%M:%S")] starting on $(hostname)

##################################
# make bash behave more robustly #
##################################
set -e
set -u
set -o pipefail


###############
# run command #
###############
group_a="SRR6026682_SRR6026683_SRR6026684_merged_trimmed,SRR6026685_SRR6026686_SRR6026687_merged_trimmed"
group_b="SRR6026688_SRR6026689_SRR6026690_merged_trimmed,SRR6026691_SRR6026692_SRR6026693_merged_trimmed"
name_a="Control"
name_b="Fmn2DKO"

singularity exec --bind $PWD/data/processed/fmn2dko/vast_out --bind /users/mirimia/projects/vast-tools/VASTDB/:/VASTDB docker://vastgroup/vast-tools:latest \
    vast-tools compare $PWD/data/processed/fmn2dko/vast_out/INCLUSION_LEVELS_FULL-mm10-4.tab \
    -a $group_a \
    -b $group_b \
    --min_dPSI 15 \
    --min_range 5 \
    --GO --print_dPSI --print_sets \
    -name_A $name_a  -name_B $name_b \
    -sp mm10 > $PWD/data/processed/fmn2dko/vast_out/summary_stats.txt

docker run docker://andresgordoortiz/vast-tools:latest \
    -v $PWD/data/processed/fmn2dko/vast_out\
    -v /users/mirimia/projects/vast-tools/VASTDB/:/VASTDB \
    bash -c "
    mkdir -p $PWD/data/processed/fmn2dko/vast_out/matt_out
    cd $PWD/data/processed/fmn2dko/vast_out/matt_out
    # Generate temporary files for each data group
    echo 'Generating temporary files for each data group...'
    matt add_val AS_NC-mm10-4-dPSI15-range5-min_ALT_use25-upreg_ALT_Control-vs-Fmn2DKO-with_dPSI-Max_dPSI3.tab GROUP AS_NC | grep -P '(MmuEX|EVENT)' > AS_NC_tmp.tab
    matt add_val CR-mm10-4-dPSI15-range5-min_ALT_use25-upreg_ALT_Control-vs-Fmn2DKO-with_dPSI.tab GROUP CR | grep -P '(MmuEX|EVENT)' > CR_tmp.tab
    matt add_val CS-mm10-4-dPSI15-range5-min_ALT_use25-upreg_ALT_Control-vs-Fmn2DKO-with_dPSI.tab GROUP CS | grep -P '(MmuEX|EVENT)' > CS_tmp.tab
    matt get_rows DiffAS-mm10-4-dPSI15-range5-min_ALT_use25-upreg_ALT_Control-vs-Fmn2DKO-with_dPSI.tab dPSI[15,100] | matt add_val - GROUP Fmn2DKO_Up | grep -P '(MmuEX|EVENT)' > up_tmp.tab
    echo 'Temporary files generated.'

    # Merge all temporary tables
    echo 'Merging all temporary tables...'
    matt add_rows AS_NC_tmp.tab CR_tmp.tab
    matt add_rows AS_NC_tmp.tab CS_tmp.tab
    matt add_rows AS_NC_tmp.tab up_tmp.tab
    echo 'Temporary tables merged.'

    # Copy merged results to a new file
    echo 'Copying merged results to a new file...'
    cp AS_NC_tmp.tab merged.tab
    rm *_tmp.tab
    echo 'Merged results copied and temporary files removed.'

    # Download necessary genome annotation files if not present
    echo 'Checking and downloading necessary genome annotation files...'
    [ ! -f mm10.gtf ] && wget -O - https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_mouse/release_M10/gencode.vM10.annotation.gtf.gz | gunzip > mm10.gtf
    [ ! -f mm10.fasta ] && wget -O - https://ftp.ebi.ac.uk/pub/databases/gencode/Gencode_mouse/release_M10/GRCm38.primary_assembly.genome.fa.gz | gunzip > mm10.fasta
    echo 'Genome annotation files checked and downloaded.'

    # Prepare input for the 'matt' tool
    echo 'Preparing input for the matt tool...'
    matt get_vast merged.tab COORD FullCO COMPLEX LENGTH -gtf mm10.gtf > matt_input_ex.tab
    echo 'Input prepared for the matt tool.'

    # Compare exons
    echo 'Comparing exons...'
    matt cmpr_exons matt_input_ex.tab START END SCAFFOLD STRAND GENEID mm10.gtf mm10.fasta Mmus 150 GROUP[Spire_Up,CR,AS_NC,CS] Matt_Out -notrbts -colors:red,white,lightgray,darkgray
    echo 'Exons compared.'

    # Create UGC motif configuration and run RNA maps
    echo 'Creating UGC motif configuration and running RNA maps...'
    echo -e 'TYPE\tNAME\tEXPR_FILE\tTHRESH\tBGMODEL\tREGEXP\tUGC\tTGC\tNA\tNA' > ugc_motif.tab
    matt rna_maps matt_input_ex.tab UPSTRM_EX_BORDER START END DOSTRM_EX_BORDER SCAFFOLD STRAND GROUP 15 50 150 mm10.fasta ugc_motif.tab TYPE NAME EXPR_FILE THRESH BGMODEL REGEXP -d UGC_map_Matt
    echo 'UGC motif configuration created and RNA maps run.'
"


###############
# end message #
###############
end_epoch=`date +%s`
echo [$(date +"%Y-%m-%d %H:%M:%S")] finished on $(hostname) after $((end_epoch-start_epoch)) seconds
