awk '
  BEGIN { FS = "\t"; OFS = "\t" }
  $3 == "exon" &&
  ($9 ~ /gene_biotype "protein_coding"/ || $9 ~ /gene_type "protein_coding"/) {
    # extract gene_name
    match($9, /gene_name "([^"]+)"/, m)
    gname = m[1]

    # unique span: chr:start-end
    span = $1 ":" $4 "-" $5

    # composite key: gene_name SUBSEP span
    key = gname SUBSEP span

    if (!seen[key]++) {
      count[gname]++
    }
  }
  END {
    for (g in count) {
      print g, count[g]
    }
  }
' $1 \
| sort -k2,2nr -k1,1 \
> coding_unique_exon_counts_per_gene.txt
