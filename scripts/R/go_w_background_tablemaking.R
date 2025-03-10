# Gene Ontology BG creation
tmp<-data.frame(bg=unique(c(
  spire_pdiff_exons[(spire_pdiff_exons$FDR > 0.05 | abs(spire_pdiff_exons$deltapsi) < 0.1), "GENE"],
  spire_pdiff_introns[(spire_pdiff_introns$FDR > 0.05 | abs(spire_pdiff_introns$deltapsi) < 0.1), "GENE"],
  spire_pdiff_alt[(spire_pdiff_alt$FDR > 0.05 | abs(spire_pdiff_alt$deltapsi) < 0.1), "GENE"]
)))
tmp<-tmp[!tmp$bg %in% c(differential_spire_exons$GENE,differential_spire_introns$GENE,differential_spire_alt$GENE),]
write.csv(tmp, "bg_spire.csv", row.names = FALSE)

tmp<-data.frame(bg=unique(c(
  fmndko_pdiff_exons[(fmndko_pdiff_exons$FDR > 0.05 | abs(fmndko_pdiff_exons$deltapsi) < 0.1), "GENE"],
  fmndko_pdiff_introns[(fmndko_pdiff_introns$FDR > 0.05 | abs(fmndko_pdiff_introns$deltapsi) < 0.1), "GENE"],
  fmndko_pdiff_alt[(fmndko_pdiff_alt$FDR > 0.05 | abs(fmndko_pdiff_alt$deltapsi) < 0.1), "GENE"]
)))
tmp<-tmp[!tmp$bg %in% c(differential_fmndko_exons$GENE,differential_fmndko_introns$GENE,differential_fmndko_alt$GENE),]
write.csv(tmp, "bg_fmndko.csv", row.names = FALSE)

write.csv(unique(c(differential_fmndko_exons$GENE,differential_fmndko_introns$GENE,differential_fmndko_alt$GENE)), "diff_fmndko.csv", row.names = FALSE)
write.csv(unique(c(differential_spire_exons$GENE,differential_spire_introns$GENE,differential_spire_alt$GENE)), "diff_spire.csv", row.names = FALSE)
