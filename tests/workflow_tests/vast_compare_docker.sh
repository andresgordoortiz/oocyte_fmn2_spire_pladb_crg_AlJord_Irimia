#!/bin/bash
# Set the species variable
species="Mm2"

# Define URLs for mouse and human VASTDB tar.gz files
file_url_mouse="https://vastdb.crg.eu/libs/vastdb.mm2.23.06.20.tar.gz"
file_url_human="https://vastdb.crg.eu/libs/vastdb.hsa.23.06.20.tar.gz"

# Define the raw data file
rawdata="INCLUSION_LEVELS_SpireData__mm10.tab"

# Define the VASTDB directory
vastdb_dir=$(pwd)/VASTDB
mkdir -p "$vastdb_dir"

# Determine the file URL and species directory based on the species variable
if [ "$species" = "Mm2" ]; then
    file_url=$file_url_mouse
    file_name=$(basename $file_url_mouse)
    species_dir="$vastdb_dir/Mm2"
elif [ "$species" = "human" ]; then
    file_url=$file_url_human
    file_name=$(basename $file_url_human)
    species_dir="$vastdb_dir/Hs2"
else
    echo "Unsupported species"
    exit 1
fi

# Check if the species directory exists, if not, download and extract the tar.gz file
if [ ! -d "$species_dir" ]; then
    wget -O "$vastdb_dir/$file_name" "$file_url"
    tar -xzf "$vastdb_dir/$file_name" -C "$vastdb_dir"
    rm "$vastdb_dir/$file_name"
else
    echo "VASTDB for $species already exists, skipping download."
fi

# Create necessary directories if they do not exist
mkdir -p $(pwd)/tests/data_tests/outdir

# Run the Docker container with the appropriate volume mounts and command
docker run -v $(pwd)/tests/data_tests/:/usr/local/vast-tools/share \
           -v $(pwd)/VASTDB:/usr/local/vast-tools/VASTDB \
           vast-tools bash -c "cd /usr/local/vast-tools/share && vast-tools compare $rawdata \
    -a Oocytes_FG_Spire12_Cont_a,Oocytes_FG_Spire12_Cont_b,Oocytes_FG_Spire12_Cont_c \
    -b Oocytes_FG_Spire12_DKO_a,Oocytes_FG_Spire12_DKO_b,Oocytes_FG_Spire12_DKO_c \
    --min_dPSI 25 \
    --min_range 5 \
    --GO \
    -sp Mm2 > summary_stats.txt"

mv tests/data_tests/*.txt tests/data_tests/outdir/
docker run -v $(pwd)/tests/data_tests/:/usr/local/vast-tools/share vast-tools \
    vast-tools plot /usr/local/vast-tools/share/Diff*.tab
mv tests/data_tests/*.pdf tests/data_tests/outdir/