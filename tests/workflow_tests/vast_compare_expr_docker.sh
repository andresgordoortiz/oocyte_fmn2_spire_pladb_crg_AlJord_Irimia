#!/bin/bash
docker run -v $(pwd)/tests/data_tests/:/usr/local/vast-tools/share vast-tools bash -c "cd /usr/local/vast-tools/share && vast-tools compare_expr TPM-mm10-6_Spire1_2_KO.tab \
    -a Oocytes_FG_Spire12_Cont_a,Oocytes_FG_Spire12_Cont_b,Oocytes_FG_Spire12_Cont_c \
    -b Oocytes_FG_Spire12_DKO_a,Oocytes_FG_Spire12_DKO_b,Oocytes_FG_Spire12_DKO_c \
    --min_fold_av 2 \
    --min_cRPKM 2 \
    --norm \
    --GO \
    -sp Mm2 > summary_stats.txt"