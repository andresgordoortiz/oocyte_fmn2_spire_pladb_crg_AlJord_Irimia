#!/bin/bash
species="Mm2"

file_url_mouse="https://vastdb.crg.eu/libs/vastdb.mm2.23.06.20.tar.gz"
file_url_human="https://vastdb.crg.eu/libs/vastdb.hsa.23.06.20.tar.gz"
rawdata="INCLUSION_LEVELS_SpireData__mm10.tab"
vastdb_dir=$(pwd)/VASTDB
mkdir -p "$vastdb_dir"

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

if [ ! -d "$species_dir" ]; then
    wget -O "$vastdb_dir/$file_name" "$file_url"
    tar -xzf "$vastdb_dir/$file_name" -C "$vastdb_dir"
    rm "$vastdb_dir/$file_name"
else
    echo "VASTDB for $species already exists, skipping download."
fi

docker run -v $(pwd)/tests/data_tests/:/usr/local/vast-tools/share \
           -v $(pwd)/VASTDB:/usr/local/vast-tools/VASTDB \
           vast-tools bash -c "cd /usr/local/vast-tools/share && vast-tools compare $rawdata \
    -a Oocytes_FG_Spire12_Cont_a,Oocytes_FG_Spire12_Cont_b,Oocytes_FG_Spire12_Cont_c \
    -b Oocytes_FG_Spire12_DKO_a,Oocytes_FG_Spire12_DKO_b,Oocytes_FG_Spire12_DKO_c \
    --min_dPSI 25 \
    --min_range 5 \
    --GO \
    -sp Mm2 > summary_stats.txt"