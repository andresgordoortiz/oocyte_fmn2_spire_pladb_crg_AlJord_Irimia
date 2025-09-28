# load libraries
library(tidyverse)
library(clusterProfiler)
library(org.Mm.eg.db)
library(enrichplot)
library(enrichR)
library(cowplot)
library(ggrepel)
library(scales)


# Read event info and differential analysis results
tub_fdr_df <- read_csv("tub_fdr.csv")[,-1]
pladb_fdr_df <- read_csv("pladb_fdr.csv")[,-1]
ssa_fdr_df <- read_csv("ssa_fdr.csv")[,-1]


# Filter for significant events
differential_tub <- na.omit(tub_fdr_df[tub_fdr_df$FDR <= 0.05 & abs(tub_fdr_df$deltapsi) >= 0.1,])
differential_pladb <- na.omit(pladb_fdr_df[pladb_fdr_df$FDR <= 0.05 & abs(pladb_fdr_df$deltapsi) >= 0.1,])
differential_ssa <- na.omit(ssa_fdr_df[ssa_fdr_df$FDR <= 0.05 & abs(ssa_fdr_df$deltapsi) >= 0.1,])

datasets <- list(tub = differential_tub,
                 pladb = differential_pladb,
                 ssa = differential_ssa)

map_genes_to_entrez <- function(genes) {
  genes <- unique(na.omit(trimws(as.character(genes))))
  if (length(genes) == 0) return(character(0))
  
  # If most look like Ensembl (ENSMUSG...), try ENSEMBL -> ENTREZ
  prop_ensembl <- mean(grepl("^ENSMUSG", genes, ignore.case = TRUE))
  if (prop_ensembl > 0.5) {
    mapped <- tryCatch(
      bitr(genes, fromType = "ENSEMBL", toType = c("ENTREZID","SYMBOL"), OrgDb = org.Mm.eg.db),
      error = function(e) data.frame()
    )
  } else {
    mapped <- tryCatch(
      bitr(genes, fromType = "SYMBOL", toType = c("ENTREZID","ENSEMBL"), OrgDb = org.Mm.eg.db),
      error = function(e) data.frame()
    )
    # fallback: try ALIAS if SYMBOL produced zero rows
    if (nrow(mapped) == 0) {
      mapped <- tryCatch(
        bitr(genes, fromType = "ALIAS", toType = c("ENTREZID","SYMBOL"), OrgDb = org.Mm.eg.db),
        error = function(e) data.frame()
      )
    }
  }
  
  if (nrow(mapped) == 0) {
    warning("No Entrez mappings found; returning original GENE values (enrichGO may fail).")
    return(genes)
  }
  unique(as.character(mapped$ENTREZID))
}

# -------------------- Plot theme & output folder --------------------
pub_theme <- theme_minimal(base_size = 12) +
  theme(
    plot.title = element_text(face = "bold", size = 14),
    axis.title = element_text(face = "bold", size = 12),
    axis.text = element_text(size = 10),
    legend.title = element_text(face = "bold", size = 11),
    legend.text = element_text(size = 9)
  )

output_dir <- "GO_enrichment_results"
dir.create(output_dir, showWarnings = FALSE, recursive = TRUE)

enrichr_dbs <- c("GO_Biological_Process_2021","GO_Molecular_Function_2021","GO_Cellular_Component_2021")

# -------------------- Main loop --------------------
for (nm in names(datasets)) {
  message("---- Processing: ", nm, " ----")
  df <- datasets[[nm]]
  genes_orig <- df$GENE
  genes_entrez <- map_genes_to_entrez(genes_orig)
  use_entrez <- length(genes_entrez) > 0 && all(grepl("^[0-9]+$", genes_entrez))
  
  message("Unique input genes: ", length(unique(na.omit(genes_orig))))
  message("Mapped Entrez IDs: ", length(genes_entrez))
  
  # run enrichGO safely
  run_enrichGO_safe <- function(gvec, ont) {
    tryCatch({
      if (use_entrez) {
        enrichGO(gene = gvec, OrgDb = org.Mm.eg.db, ont = ont, keyType = "ENTREZID",
                 pAdjustMethod = "BH", pvalueCutoff = 0.05, qvalueCutoff = 0.05, readable = TRUE)
      } else {
        # supply original SYMBOLs if mapping failed
        enrichGO(gene = unique(na.omit(as.character(genes_orig))), OrgDb = org.Mm.eg.db, ont = ont,
                 keyType = "SYMBOL", pAdjustMethod = "BH", pvalueCutoff = 0.05, qvalueCutoff = 0.05, readable = TRUE)
      }
    }, error = function(e) {
      message("enrichGO error (", nm, ", ", ont, "): ", e$message)
      NULL
    })
  }
  
  ego_bp <- run_enrichGO_safe(genes_entrez, "BP")
  ego_mf <- run_enrichGO_safe(genes_entrez, "MF")
  ego_cc <- run_enrichGO_safe(genes_entrez, "CC")
  
  # Save CSVs if results exist
  save_if <- function(x, suffix) {
    if (!is.null(x) && nrow(as.data.frame(x)) > 0) {
      f <- file.path(output_dir, paste0(nm, "_", suffix, ".csv"))
      write.csv(as.data.frame(x), f, row.names = FALSE)
      message("Saved: ", f)
    }
  }
  save_if(ego_bp, "GO_BP")
  save_if(ego_mf, "GO_MF")
  save_if(ego_cc, "GO_CC")
  
  # Enrichr (optional)
  if (length(unique(na.omit(genes_orig))) >= 5) {
    try({
      enr <- enrichr(unique(na.omit(as.character(genes_orig))), enrichr_dbs)
      for (db in names(enr)) {
        if (!is.null(enr[[db]]) && nrow(enr[[db]]) > 0) {
          fdb <- file.path(output_dir, paste0(nm, "_Enrichr_", db, ".csv"))
          write.csv(enr[[db]], fdb, row.names = FALSE)
          message("Saved Enrichr: ", fdb)
        }
      }
    }, silent = TRUE)
  }
  
  # -------------------- Plots --------------------
  plots <- list()
  
  if (!is.null(ego_bp) && nrow(as.data.frame(ego_bp)) > 0) {
    p_dot <- dotplot(ego_bp, showCategory = 20, orderBy = "Count") +
      ggtitle(paste0("GO Biological Process — ", nm)) + pub_theme +
      theme(axis.text.y = element_text(size = 9))
    plots$bp_dot <- p_dot
    ggsave(file.path(output_dir, paste0(nm, "_BP_dot.pdf")), p_dot, width = 7, height = 6)
    ggsave(file.path(output_dir, paste0(nm, "_BP_dot.png")), p_dot, width = 7, height = 6, dpi = 300)
    
    p_bar <- barplot(ego_bp, showCategory = 12, title = paste0("GO BP (top) — ", nm)) + pub_theme
    plots$bp_bar <- p_bar
    ggsave(file.path(output_dir, paste0(nm, "_BP_bar.pdf")), p_bar, width = 6.5, height = 5)
    ggsave(file.path(output_dir, paste0(nm, "_BP_bar.png")), p_bar, width = 6.5, height = 5, dpi = 300)
    
    # cnet (limited categories for readability)
    top_k <- min(6, nrow(as.data.frame(ego_bp)))
    try({
      p_cnet <- cnetplot(ego_bp, showCategory = top_k, foldChange = NULL, circular = FALSE, colorCategory = FALSE) +
        ggtitle(paste0("Gene-Concept Network — ", nm)) + pub_theme
      plots$bp_cnet <- p_cnet
      ggsave(file.path(output_dir, paste0(nm, "_BP_cnet.pdf")), p_cnet, width = 8, height = 6)
      ggsave(file.path(output_dir, paste0(nm, "_BP_cnet.png")), p_cnet, width = 8, height = 6, dpi = 300)
    }, silent = TRUE)
    
    # combined multi-panel (if available)
    avail <- plots[c("bp_dot","bp_bar","bp_cnet")]
    avail <- avail[!sapply(avail, is.null)]
    if (length(avail) >= 2) {
      combined <- plot_grid(plotlist = avail[1:min(3,length(avail))], ncol = 2, labels = "AUTO")
      ggsave(file.path(output_dir, paste0(nm, "_BP_summary_combined.pdf")), combined, width = 11, height = 8)
      ggsave(file.path(output_dir, paste0(nm, "_BP_summary_combined.png")), combined, width = 11, height = 8, dpi = 300)
    }
  } else {
    message("No significant BP enrichment for ", nm)
  }
  
  # small summary
  summary_file <- file.path(output_dir, paste0(nm, "_summary.txt"))
  sink(summary_file)
  cat("Dataset:", nm, "\n")
  cat("Input genes (unique):", length(unique(na.omit(genes_orig))), "\n")
  cat("Mapped Entrez (count):", length(genes_entrez), "\n")
  cat("GO BP terms:", ifelse(is.null(ego_bp), 0, nrow(as.data.frame(ego_bp))), "\n")
  cat("GO MF terms:", ifelse(is.null(ego_mf), 0, nrow(as.data.frame(ego_mf))), "\n")
  cat("GO CC terms:", ifelse(is.null(ego_cc), 0, nrow(as.data.frame(ego_cc))), "\n")
  sink()
  message("Wrote summary: ", summary_file)
}

message("Completed. All outputs in: ", normalizePath(output_dir))
