library(dplyr)
library(ggplot2)
library(ggpubr)
library(gridExtra)
library(showtext)    # font_add_google(), showtext_auto()

# 1) Read event info
event_info <- read.delim("EVENT_INFO-mm10.tab")

# Import betAS output tables
tub_fdr_df<-read_csv("tub_fdr.csv")[,-1]
pladb_fdr_df<-read_csv("pladb_fdr.csv")[,-1]
ssa_fdr_df<-read_csv("ssa_fdr.csv")[,-1]

differential_tub<-na.omit(tub_fdr_df[tub_fdr_df$FDR <= 0.05 & abs(tub_fdr_df$deltapsi) >= 0.1,])

differential_pladb<-na.omit(pladb_fdr_df[pladb_fdr_df$FDR <= 0.05 & abs(pladb_fdr_df$deltapsi) >= 0.1,])

differential_ssa<-na.omit(ssa_fdr_df[ssa_fdr_df$FDR <= 0.05 & abs(ssa_fdr_df$deltapsi) >= 0.1,])

# Save separate GC and Length intron plots for SSA, Tubercidin, and Pladb — PNG + PDF (high-res)
library(dplyr)
library(ggplot2)
library(ggpubr)
library(readr)
library(showtext)
library(grid)    # unit()
library(gridExtra)

# ---- showtext / font (high DPI) ----
preferred_font <- "Roboto"
font_add_google(preferred_font)
showtext::showtext_opts(dpi = 600)   # <- high DPI for consistent output
showtext_auto()
base_family <- preferred_font

# ---- styling utilities (rpvios style) ----
cell_blue <- "#00A1D7"
make_cell_palette <- function(n, main = cell_blue) {
  anchors <- c(main, "#0073A8", "#9EE8FB", "#4D4D4D", "#E69F00")
  if (n <= length(anchors)) anchors[1:n] else colorRampPalette(anchors)(n)
}
theme_cellpub <- function(base_size = 16, base_family_in = NULL) {
  if (is.null(base_family_in)) base_family_in <- get0("base_family", ifnotfound = "sans")
  theme_classic(base_size = base_size, base_family = base_family_in) %+replace%
    theme(
      axis.line = element_line(linewidth = 0.9, colour = "#222222"),
      axis.ticks = element_line(linewidth = 0.9, colour = "#222222"),
      axis.ticks.length = unit(3, "pt"),
      axis.title = element_text(family = base_family_in, face = "plain", size = rel(1.0)),
      axis.text = element_text(family = base_family_in, size = rel(0.95), colour = "#111111"),
      legend.position = "none",
      legend.direction = "horizontal",
      legend.key.size = unit(10, "pt"),
      legend.background = element_blank(),
      legend.title = element_blank(),
      legend.text = element_text(family = base_family_in, size = rel(0.95)),
      panel.grid.major.y = element_line(color = alpha("#666666", 0.10), linetype = "dashed", linewidth = 0.4),
      panel.grid.major.x = element_blank(),
      strip.background = element_blank(),
      strip.text = element_text(face = "bold", size = rel(1.0), family = base_family_in),
      plot.title = element_text(face = "bold", size = rel(1.05), hjust = 0.5, family = base_family_in),
      plot.subtitle = element_text(size = rel(0.95), hjust = 0.5, family = base_family_in),
      plot.caption = element_text(size = rel(0.85), colour = "#666666", family = base_family_in),
      plot.margin = margin(6, 6, 6, 6)
    )
}
my_theme <- theme_cellpub(base_size = 16, base_family_in = base_family)

# ---- helper: GC function ----
gc_content <- function(seqs) {
  sapply(seqs, function(seq) {
    if (is.na(seq)) return(NA_real_)
    seq <- toupper(as.character(seq))
    chars <- strsplit(seq, "")[[1]]
    gc  <- sum(chars %in% c("G","C"))
    n   <- length(chars)
    if(n==0) return(NA_real_)
    100 * gc / n
  })
}

# ---- main plotting function (saves separate GC + Length PNG + PDF) ----
make_and_save_introns <- function(dataset_name,
                                  differential_df, fdr_df, event_info,
                                  out_prefix = "introns", sample_max = 1000) {
  ds_label <- toupper(dataset_name)
  message("Processing: ", ds_label)
  # differential intronic events
  introns_gc <- differential_df %>%
    filter(grepl("INT", EVENT)) %>%
    left_join(select(event_info, EVENT, Seq_A, LE_o), by = "EVENT") %>%
    mutate(gc = gc_content(Seq_A),
           splicing = if_else(deltapsi < 0, "Skipped", "Included"))
  if(nrow(introns_gc) == 0) {
    message("  -> no differential introns for ", ds_label, "; skipping.")
    return(invisible(NULL))
  }
  # unchanged pool (sample)
  unchanged_pool <- fdr_df %>% filter(grepl("INT", EVENT)) %>%
    filter(!EVENT %in% differential_df$EVENT) %>%
    left_join(select(event_info, EVENT, Seq_A, LE_o), by = "EVENT") %>%
    filter(!is.na(Seq_A))
  sample_size <- min(sample_max, nrow(unchanged_pool))
  if(sample_size == 0) {
    message("  -> no unchanged introns to sample for ", ds_label, "; skipping.")
    return(invisible(NULL))
  }
  unchanged_gc <- unchanged_pool %>%
    sample_n(size = sample_size) %>%
    mutate(gc = gc_content(Seq_A), splicing = "Unchanged")
  all_introns <- bind_rows(introns_gc, unchanged_gc) %>%
    mutate(splicing = factor(splicing, levels = c("Included","Skipped","Unchanged")))
  if(all(is.na(all_introns$gc))) {
    message("  -> no GC values available for ", ds_label, "; skipping.")
    return(invisible(NULL))
  }
  
  # comparisons & palette
  comparisons <- list(
    c("Included", "Skipped"),
    c("Included", "Unchanged"),
    c("Skipped",  "Unchanged")
  )
  palette <- make_cell_palette(3); names(palette) <- c("Included","Skipped","Unchanged")
  
  # ---- GC plot ----
  p_gc <- ggplot(all_introns, aes(x = splicing, y = gc, fill = splicing)) +
    geom_boxplot(outlier.shape = NA, alpha = 0.9, width = 0.6) +
    geom_jitter(width = 0.15, alpha = 0.5, size = 1.6) +
    stat_compare_means(method = "wilcox.test", comparisons = comparisons, label = "p.signif", label.size = 5) +
    scale_fill_manual(values = palette) +
    labs(x = "Splicing Outcome", y = "GC Content (%)",
         title = paste0(ds_label, ": Introns — GC content")) +
    my_theme +
    theme(axis.title = element_text(family = base_family),
          axis.text = element_text(family = base_family))
  
  # ---- Length plot (statistics on original data, display clipped) ----
  # Remove extreme outliers by using 95th percentile clipping for display only
  threshold_95 <- quantile(all_introns$LE_o, 0.95, na.rm = TRUE)
  
  # Create plot data - keep original values for statistics
  plot_data <- all_introns %>%
    filter(!is.na(LE_o)) %>%
    mutate(
      LE_o_display = pmin(LE_o, threshold_95),  # Cap display values at 95th percentile
      is_outlier = LE_o > threshold_95
    )
  
  if(nrow(plot_data) == 0) {
    p_len <- NULL
    message("  -> no length data for ", ds_label, "; skipping length plot.")
  } else {
    message("  -> creating length plot for ", ds_label, " with ", nrow(plot_data), " introns")
    
    # Calculate statistics on ORIGINAL data (including outliers)
    stat_results <- purrr::map_dfr(comparisons, function(comp) {
      g1 <- comp[1]; g2 <- comp[2]
      
      # Use original LE_o values for statistical test
      data_g1 <- plot_data$LE_o[plot_data$splicing == g1]
      data_g2 <- plot_data$LE_o[plot_data$splicing == g2]
      
      if(length(data_g1) < 1 || length(data_g2) < 1) {
        return(tibble(group1 = g1, group2 = g2, p.value = NA_real_))
      }
      
      test_result <- tryCatch({
        wilcox.test(data_g1, data_g2, exact = FALSE)
      }, error = function(e) {
        list(p.value = NA_real_)
      })
      
      tibble(group1 = g1, group2 = g2, p.value = test_result$p.value)
    })
    
    # Convert p-values to significance symbols
    stat_results <- stat_results %>%
      mutate(
        p.signif = case_when(
          is.na(p.value) ~ "ns",
          p.value <= 0.001 ~ "***",
          p.value <= 0.01 ~ "**", 
          p.value <= 0.05 ~ "*",
          TRUE ~ "ns"
        )
      )  # Only show significant results
    
    # Position bars based on CLIPPED data range for visibility
    if(nrow(stat_results) > 0) {
      max_display <- max(plot_data$LE_o_display, na.rm = TRUE)
      step_size <- max_display * 0.08  # 8% steps
      
      stat_results <- stat_results %>%
        mutate(
          y.position = max_display + step_size * row_number(),
          xmin = group1,
          xmax = group2,
          label = p.signif
        )
    }
    
    # Create plot with clipped data for display
    p_len <- ggplot(plot_data, aes(x = splicing, y = LE_o_display, fill = splicing)) +
      geom_boxplot(outlier.shape = NA, alpha = 0.9, width = 0.6) +
      geom_jitter(width = 0.15, alpha = 0.5, size = 1.6) +
      scale_fill_manual(values = palette) +
      labs(x = "Splicing Outcome", y = "Intron Length (nt)",
           title = paste0(ds_label, ": Introns — Length")) +
      my_theme +
      theme(axis.title = element_text(family = base_family),
            axis.text = element_text(family = base_family))
    
    # Add significance bars if any exist
    if(nrow(stat_results) > 0) {
      p_len <- p_len +
        stat_pvalue_manual(stat_results, 
                           xmin = "group1", xmax = "group2",
                           y.position = "y.position", label = "label",
                           tip.length = 0.02, label.size = 5)
      
      # Adjust y-axis to accommodate significance bars
      max_bar_pos <- max(stat_results$y.position)
      p_len <- p_len + coord_cartesian(ylim = c(NA, max_bar_pos * 1.05))
    }
    
    # Add indicator for clipped outliers if any exist
    n_outliers <- sum(plot_data$is_outlier)
    if(n_outliers > 0) {
      p_len <- p_len + 
        labs(caption = paste0("Note: ", n_outliers, " outliers > ", round(threshold_95), " nt clipped for display; statistics calculated on full data"))
    }
  }
  
  # ---- Save files: separate GC and Length PNG + PDF ----
  gc_png  <- paste0(out_prefix, "_", dataset_name, "_gc.png")
  gc_pdf  <- paste0(out_prefix, "_", dataset_name, "_gc.pdf")
  len_png <- paste0(out_prefix, "_", dataset_name, "_length.png")
  len_pdf <- paste0(out_prefix, "_", dataset_name, "_length.pdf")
  
  # Save GC
  ggsave(gc_png, plot = p_gc, width = 6, height = 5, dpi = 600)
  ggsave(gc_pdf, plot = p_gc, device = cairo_pdf, width = 6, height = 5)
  message("  -> saved: ", gc_png, " and ", gc_pdf)
  
  # Save Length (if exists)
  if(!is.null(p_len)) {
    ggsave(len_png, plot = p_len, width = 6, height = 5, dpi = 600)
    ggsave(len_pdf, plot = p_len, device = cairo_pdf, width = 6, height = 5)
    message("  -> saved: ", len_png, " and ", len_pdf)
  }
  
  invisible(list(gc = p_gc, length = p_len))
}

# ---- Run for SSA, tub (tubercidin), pladb ----
# Assumes objects: differential_ssa, differential_tub, differential_pladb,
# and ssa_fdr_df, tub_fdr_df, pladb_fdr_df and event_info exist.
datasets <- list(
  ssa   = list(diff = differential_ssa, fdr = ssa_fdr_df),
  tub   = list(diff = differential_tub, fdr = tub_fdr_df),
  pladb = list(diff = differential_pladb, fdr = pladb_fdr_df)
)

results <- list()
for(nm in names(datasets)) {
  ds <- datasets[[nm]]
  results[[nm]] <- tryCatch({
    make_and_save_introns(dataset_name = nm,
                          differential_df = ds$diff,
                          fdr_df = ds$fdr,
                          event_info = event_info,
                          out_prefix = "introns")
  }, error = function(e) {
    message("ERROR processing ", nm, ": ", e$message)
    NULL
  })
}

message("Done. Plots saved for datasets: ", paste(names(Filter(Negate(is.null), results)), collapse = ", "))