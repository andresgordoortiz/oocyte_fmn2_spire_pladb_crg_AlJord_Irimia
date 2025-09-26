library(ggupset)
library(ggplot2)
library(dplyr)
library(tidyr)
library(scales)
library(purrr)
library(showtext)
library(scales)

# Import betAS output tables
tub_fdr_df<-read_csv("tub_fdr.csv")[,-1]
pladb_fdr_df<-read_csv("pladb_fdr.csv")[,-1]
ssa_fdr_df<-read_csv("ssa_fdr.csv")[,-1]

differential_tub <- na.omit(tub_fdr_df[tub_fdr_df$FDR <= 0.05 & abs(tub_fdr_df$deltapsi) >= 0.1,])
differential_pladb <- na.omit(pladb_fdr_df[pladb_fdr_df$FDR <= 0.05 & abs(pladb_fdr_df$deltapsi) >= 0.1,])
differential_ssa <- na.omit(ssa_fdr_df[ssa_fdr_df$FDR <= 0.05 & abs(ssa_fdr_df$deltapsi) >= 0.1,])

# Get all unique genes from all three datasets
all_genes <- unique(c(differential_tub$GENE, differential_pladb$GENE, differential_ssa$GENE))

# Create treatment combinations for each gene
gene_list <- data.frame(
  Gene = all_genes,
  Treatment = sapply(all_genes, function(gene) {
    treatments <- c()
    if (gene %in% differential_tub$GENE) treatments <- c(treatments, "Tub")
    if (gene %in% differential_pladb$GENE) treatments <- c(treatments, "Pladb")
    if (gene %in% differential_ssa$GENE) treatments <- c(treatments, "Ssa")
    paste(treatments, collapse = ", ")
  })
)

# Optional: Add a column for the number of treatments
gene_list$Treatment_Count <- sapply(strsplit(gene_list$Treatment, ", "), length)


#all_genes <- unique(c(differential_tub$GENE, differential_pladb$GENE, differential_ssa$GENE))

# Create a proper data frame for ggupset
# We need to create a tibble with a list column
gene_list_upset <- tibble(
  Gene = all_genes
) %>%
  mutate(
    Treatments = map(Gene, function(gene) {
      treatments <- c()
      if (gene %in% differential_tub$GENE) treatments <- c(treatments, "Tub")
      if (gene %in% differential_pladb$GENE) treatments <- c(treatments, "Pladb")
      if (gene %in% differential_ssa$GENE) treatments <- c(treatments, "Ssa")
      return(treatments)
    })
  )

theme_cellpub <- function(base_size = 18, base_family = "Roboto") {
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

# Then use:
upset_plot + theme_cellpub(base_family = "Roboto")

# ------------------------
# 7) Saving recommendations (vector + high-res raster)
# ------------------------
# Single-column figure example (adjust sizes to journal specs if needed)
ggsave("upset_genes.pdf", plot = upset_plot + theme_cellpub(base_family = "Roboto"), width = 6.5, height = 4.2, device = cairo_pdf)
ggsave("upset_genes.png", plot = upset_plot + theme_cellpub(base_family = "Roboto"), width = 6.5, height = 4.2, dpi = 600)
