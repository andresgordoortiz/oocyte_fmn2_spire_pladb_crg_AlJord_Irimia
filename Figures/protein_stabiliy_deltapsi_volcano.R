library(readxl)
library(tidyverse)
library(ggrepel)

katarina_protein_stable_oocyte <- read_excel("41556_2024_1442_MOESM4_ESM.xlsx", 
                                             sheet = "TableS1", col_types = c("text", 
                                                                              "text", "text", "text", "text", "text", 
                                                                              "text", "numeric", "text", "text", 
                                                                              "text", "numeric", "numeric", "numeric", 
                                                                              "numeric", "numeric", "numeric", 
                                                                              "numeric", "numeric", "numeric", 
                                                                              "numeric", "numeric", "numeric", 
                                                                              "numeric", "numeric", "numeric", 
                                                                              "numeric", "numeric", "numeric", 
                                                                              "numeric", "numeric")) %>%
  rename("GENE"="gene_name", "stability"="mean percent H") 
  katarina_protein_stable_oocyte<-filter(katarina_protein_stable_oocyte, 
                                         !is.na(katarina_protein_stable_oocyte$stability))

# Import betAS output tables
tub_fdr_df<-read_csv("tub_fdr.csv")[,-1]
pladb_fdr_df<-read_csv("pladb_fdr.csv")[,-1]
ssa_fdr_df<-read_csv("ssa_fdr.csv")[,-1]



differential_tub<-na.omit(tub_fdr_df[tub_fdr_df$FDR <= 0.05 & abs(tub_fdr_df$deltapsi) >= 0.1,])

differential_pladb<-na.omit(pladb_fdr_df[pladb_fdr_df$FDR <= 0.05 & abs(pladb_fdr_df$deltapsi) >= 0.1,])

differential_ssa<-na.omit(ssa_fdr_df[ssa_fdr_df$FDR <= 0.05 & abs(ssa_fdr_df$deltapsi) >= 0.1,])

sig_genes<-unique(c(differential_tub$GENE,differential_pladb$GENE,differential_ssa$GENE))

splicing_data <- getDataset(pathTables = paste0(getwd(),"/new_data_INCLUSION_LEVELS_FULL-mm10.tab"), 
                            tool = "vast-tools")
backgound_genes<-filter(splicing_data, !splicing_data$GENE %in% sig_genes)




library(tidyverse)
library(ggrepel)

# 1) Combine differential lists
differential_all <- bind_rows(
  differential_tub %>% mutate(group = "Differential_TUB"),
  differential_pladb %>% mutate(group = "Differential_PLADB"),
  differential_ssa %>% mutate(group = "Differential_SSA")
)

# 2) Count in how many groups each gene appears
gene_counts <- differential_all %>%
  group_by(GENE) %>%
  summarize(n_groups = n_distinct(group), .groups = "drop")

# 3) Keep one row per gene per group for plotting points
differential_all <- differential_all %>%
  group_by(GENE, group) %>%
  slice(1) %>%
  ungroup() %>%
  left_join(katarina_protein_stable_oocyte %>% select(GENE, stability), by = "GENE") %>%
  left_join(gene_counts, by = "GENE")

# 4) Define highlighting categories based on number of groups AND stability
differential_all <- differential_all %>%
  mutate(
    highlight = case_when(
      n_groups == 3 & stability > 10 ~ "All_3_HighStability",
      n_groups == 2 & stability > 10 ~ "TwoGroups_HighStability",
      stability > 10 ~ "High_Stability",
      TRUE ~ "Other"
    ),
    point_size = case_when(
      highlight == "All_3_HighStability" ~ 5,
      highlight == "TwoGroups_HighStability" ~ 3.5,
      highlight == "High_Stability" ~ 2.5,
      TRUE ~ 1.5
    ),
    point_color = case_when(
      highlight == "All_3_HighStability" ~ "red",
      highlight == "TwoGroups_HighStability" ~ "#FF8C00",   # orange-ish for intersection of 2
      highlight == "High_Stability" ~ "#00A1D7",            # cell blue
      TRUE ~ "#999999"
    )
  )

# 5) Prepare labels: only one per gene
label_genes <- differential_all %>%
  filter(highlight != "Other") %>%
  group_by(GENE) %>%
  slice_max(point_size, n = 1) %>%  # choose most prominent category if duplicated
  ungroup() %>%
  mutate(fontface_label = ifelse(highlight == "All_3_HighStability", "bold", "plain"))


preferred_font<-"Roboto"
font_add_google(preferred_font)
showtext::showtext_opts(dpi=600)
showtext_auto()   # ensures text is rendered via showtext (good for PDFs via cairo)

base_family <- preferred_font
# 6) Volcano-style plot
p_volcano <- ggplot(differential_all, aes(x = deltapsi, y = stability)) +
  geom_point(aes(size = point_size, color = point_color), alpha = 0.7, na.rm = TRUE) +
  scale_size_identity() +
  scale_color_identity() +
  geom_hline(yintercept = 10, linetype = "dashed", color = "#666666") +
  geom_text_repel(
    data = label_genes,
    aes(label = GENE),
    size = 3,
    max.overlaps = 20,
    fontface = label_genes$fontface_label
  ) +
  labs(
    x = "ΔPSI",
    y = "Stability",
    title = "Differential Genes: ΔPSI vs Stability"
  ) +
  theme_cellpub(base_size = 14)

p_volcano

# ------------------------
# 7) Saving recommendations (vector + high-res raster)
# ------------------------
# Single-column figure example (adjust sizes to journal specs if needed)
ggsave("volcano_stability_deltapsi.pdf", plot = p_volcano, width = 6.5, height = 4.2, device = cairo_pdf)
ggsave("volcano_stability_deltapsi.pdf", plot = p_volcano, width = 6.5, height = 4.2, dpi = 600)