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

# ------------------------
# 2) Palette anchored on Cell blue
# ------------------------
cell_blue <- "#00A1D7"
make_cell_palette <- function(n, main = cell_blue) {
  anchors <- c(
    main,        # anchor blue
    "#0073A8",   # darker blue
    "#9EE8FB",   # very light tint
    "#4D4D4D",   # neutral dark (for outlines/contrasts)
    "#E69F00"    # warm accent (sparingly)
  )
  if (n <= length(anchors)) {
    anchors[1:n]
  } else {
    colorRampPalette(anchors)(n)
  }
}

# ------------------------
# 3) Publication theme (cell-inspired)
# ------------------------
theme_cellpub <- function(base_size = 18, base_family = base_family) {
  theme_classic(base_size = base_size, base_family = base_family) %+replace%
    theme(
      axis.line = element_line(linewidth = 0.9, colour = "#222222"),
      axis.ticks = element_line(linewidth = 0.9, colour = "#222222"),
      axis.ticks.length = unit(3, "pt"),
      axis.title = element_text(face = "plain", size = rel(1.0)),
      axis.text = element_text(size = rel(0.95), colour = "#111111"),
      legend.position = "top",
      legend.direction = "horizontal",
      legend.key.size = unit(10, "pt"),
      legend.background = element_blank(),
      legend.title = element_blank(),
      legend.text = element_text(size = rel(0.95)),
      panel.grid.major.y = element_line(color = alpha("#666666", 0.10), linetype = "dashed", linewidth = 0.4),
      panel.grid.major.x = element_blank(),
      strip.background = element_blank(),
      strip.text = element_text(face = "bold", size = rel(1.0)),
      plot.title = element_text(face = "bold", size = rel(1.05), hjust = 0),
      plot.subtitle = element_text(size = rel(0.95), hjust = 0),
      plot.caption = element_text(size = rel(0.85), colour = "#666666"),
      plot.margin = margin(6, 6, 6, 6)
    )
}

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