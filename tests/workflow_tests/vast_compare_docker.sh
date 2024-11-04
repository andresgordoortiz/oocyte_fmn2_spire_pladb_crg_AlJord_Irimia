#!/bin/bash
docker run -v $(pwd)/tests/data_tests/:/usr/local/vast-tools/share vast-tools bash -c "cd /usr/local/vast-tools/share && vast-tools compare INCLUSION_LEVELS_SpireData__mm10.tab \
    -a Oocytes_FG_Spire12_Cont_a,Oocytes_FG_Spire12_Cont_b,Oocytes_FG_Spire12_Cont_c \
    -b Oocytes_FG_Spire12_DKO_a,Oocytes_FG_Spire12_DKO_b,Oocytes_FG_Spire12_DKO_c \
    --min_dPSI 25 \
    --min_range 5 > summary_stats.txt"
