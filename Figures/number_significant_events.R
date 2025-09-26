# Import betAS output tables
tub_fdr_df<-read_csv("tub_fdr.csv")[,-1]
pladb_fdr_df<-read_csv("pladb_fdr.csv")[,-1]
ssa_fdr_df<-read_csv("ssa_fdr.csv")[,-1]

# Extract significant (FDR<=0.05 & |deltaPSI| > 10%)

differential_tub<-na.omit(tub_fdr_df[tub_fdr_df$FDR <= 0.05 & abs(tub_fdr_df$deltapsi) >= 0.1,])

differential_pladb<-na.omit(pladb_fdr_df[pladb_fdr_df$FDR <= 0.05 & abs(pladb_fdr_df$deltapsi) >= 0.1,])

differential_ssa<-na.omit(ssa_fdr_df[ssa_fdr_df$FDR <= 0.05 & abs(ssa_fdr_df$deltapsi) >= 0.1,])

#----- PREPARE DF -------

library(dplyr)
library(tidyr)
library(ggplot2)

# classification function (as you used)
classify_event <- function(x) {
  ifelse(grepl("EX", x), "Exon",
         ifelse(grepl("INT", x), "Intron",
                ifelse(grepl("ALTD", x), "Alt5",
                       ifelse(grepl("ALTA", x), "Alt3", NA)
                )
         )
  )
}

# canonical order
levels_order <- c("Exon", "Intron", "Alt5", "Alt3")

# build long dataframe (one row per event occurrence)
long_df <- bind_rows(
  tibble(Condition = "Tubercidin",   Event = classify_event(differential_tub$EVENT), Inclusion=differential_tub$deltapsi>0),
  tibble(Condition = "Pladienolide B", Event = classify_event(differential_pladb$EVENT),Inclusion=differential_pladb$deltapsi>0),
  tibble(Condition = "Spliceostatin A",   Event = classify_event(differential_ssa$EVENT),Inclusion=differential_ssa$deltapsi>0)
) %>%
  filter(!is.na(Event)) %>%
  mutate(
    Event = factor(Event, levels = levels_order),
    Condition = factor(Condition, levels = c("Tubercidin", "Pladienolide B", "Spliceostatin A"))
  )

# summary counts (wide) if you still want it
fig_summary <- long_df %>%
  count(Condition, Event) %>%
  pivot_wider(names_from = Condition, values_from = n, values_fill = 0) %>%
  arrange(match(Event, levels_order))

print(fig_summary)  # optional: view the counts table

# ---------- PLOT Figure ----------

library(ggplot2)
library(dplyr)
library(forcats)
library(showtext)
library(scales)

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

# ------------------------
# 4) Prepare palette matched to actual Condition levels
# ------------------------
conds <- levels(factor(long_df$Condition))
pal <- setNames(make_cell_palette(length(conds), main = cell_blue), conds)

# ------------------------
# 5) Order Events by frequency for nice visual ordering (optional)
# ------------------------
long_df <- long_df %>%
  mutate(Event = fct_infreq(as.factor(Event)))  # most frequent first

# ------------------------
# 6) The adapted plot (bigger fonts, crisp lines, labels)
# ------------------------
p <- ggplot(long_df, aes(x = Event, fill = Condition)) +
  geom_bar(position = position_dodge(width = 0.9),
           width = 0.75,
           color = "black",        # border color
           linewidth = 0.35) +     # border thickness (use linewidth, not size)
  geom_text(stat = "count",
            aes(label = ..count..),
            position = position_dodge(width = 0.9),
            vjust = -0.45,
            family = base_family,
            size = 2) +            # label size (in pts)
  geom_line(aes(x=Event, y=Inclusion)) +
  scale_fill_manual(values = pal) +
  scale_y_continuous(expand = expansion(mult = c(0, 0.06))) +
  labs(x = "Event type", y = "Significant Splicing Events") +
  coord_cartesian(clip = "off") +
  theme_cellpub(base_size = 10, base_family = base_family) +
  theme(
    axis.text.x = element_text(angle = 0, vjust = 0.5),  # set to 45 if many categories
    legend.position = "top",
    legend.spacing.x = unit(6, "pt")
  )

# Print
print(p)

# ------------------------
# 7) Saving recommendations (vector + high-res raster)
# ------------------------
# Single-column figure example (adjust sizes to journal specs if needed)
ggsave("figure_cellpub_event_counts.pdf", plot = p, width = 6.5, height = 4.2, device = cairo_pdf)
ggsave("figure_cellpub_event_counts.png", plot = p, width = 6.5, height = 4.2, dpi = 600)















