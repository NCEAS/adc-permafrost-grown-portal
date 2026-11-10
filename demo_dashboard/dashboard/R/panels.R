# Shared plotting helpers used by both index.qmd and scripts/make_figures.R
suppressPackageStartupMessages({
  library(terra); library(sf); library(dplyr); library(tidyr)
  library(ggplot2); library(scales)
})

YES_COL <- "#1f78b4"; NO_COL <- "#bdbdbd"
PG_GREEN <- "#1b5e4b"; PG_GOLD <- "#c9892b"; PG_GOLD_DK <- "#9a6410"

theme_pg <- function(base_size = 12) {
  theme_minimal(base_size = base_size) +
    theme(panel.grid.minor = element_blank(),
          plot.title    = element_text(face = "bold", size = base_size + .5,
                                       colour = PG_GREEN),
          plot.subtitle = element_text(size = base_size - 1.5, colour = "#5b6770"),
          axis.title    = element_text(size = base_size - 1.5),
          legend.position = "top", legend.title = element_blank())
}

#' Share of borehole logs reporting each condition
indicator_plot <- function(bh) {
  ind <- bh |>
    select(`Permafrost present` = permafrost, `Talik (unfrozen zone)` = talik,
           `Visible ground ice` = visible_ice, `Massive ground ice` = massive_ice) |>
    pivot_longer(everything(), names_to = "indicator", values_to = "value") |>
    count(indicator, value) |>
    group_by(indicator) |> mutate(pct = n / sum(n) * 100) |> ungroup() |>
    mutate(indicator = factor(indicator, levels = rev(c(
      "Permafrost present", "Talik (unfrozen zone)",
      "Visible ground ice", "Massive ground ice"))))
  lab <- ind |> filter(value == "Yes") |>
    mutate(inside = pct > 12,
           hj     = ifelse(inside, 1.1, -0.12),
           col    = ifelse(inside, "white", "#22272b"),
           txt    = sprintf("%d (%s)", n,
                     ifelse(pct < 1, sprintf("%.1f%%", pct), sprintf("%.0f%%", pct))))

  ggplot(ind, aes(pct, indicator, fill = value)) +
    geom_col(width = .62, position = position_stack(reverse = TRUE)) +
    geom_text(data = lab, aes(label = txt, hjust = hj, colour = col),
              size = 3.3, fontface = "bold", show.legend = FALSE) +
    scale_colour_identity() +
    scale_fill_manual(values = c(Yes = YES_COL, No = NO_COL)) +
    scale_x_continuous(labels = label_percent(scale = 1),
                       expand = expansion(c(0, .06))) +
    labs(title = sprintf("%d borehole records, Bethel area", nrow(bh)),
         subtitle = "Share of logs reporting each condition", x = NULL, y = NULL) +
    theme_pg()
}

#' Depth below the surface at which drillers logged frozen ground
depth_plot <- function(bh) {
  med <- median(bh$pf_top_m, na.rm = TRUE)
  ggplot(filter(bh, !is.na(pf_top_m)), aes(pf_top_m)) +
    geom_histogram(binwidth = .5, fill = YES_COL, colour = "white", linewidth = .25) +
    geom_vline(xintercept = med, colour = PG_GOLD, linewidth = .8) +
    annotate("text", x = med, y = Inf, vjust = 1.6, hjust = -0.08,
             label = sprintf("median %.1f m", med), colour = PG_GOLD_DK, size = 3.4) +
    labs(title = sprintf("How deep the frozen ground starts (n = %d)",
                         sum(!is.na(bh$pf_top_m))),
         subtitle = "Depth below the surface at which drillers logged frozen ground",
         x = "Depth to frozen ground (m)", y = "Boreholes") +
    theme_pg()
}

#' Four-panel map of the borehole indicators (static companion to the web map)
panel_map <- function(bh) {
  pan <- bh |>
    select(lon, lat,
           `Near-surface permafrost` = permafrost,
           `Sub-aerial talik`        = talik,
           `Visible ground ice`      = visible_ice,
           `Massive ground ice`      = massive_ice) |>
    pivot_longer(-c(lon, lat), names_to = "panel", values_to = "value") |>
    mutate(panel = factor(panel, levels = c("Near-surface permafrost",
                                            "Sub-aerial talik",
                                            "Visible ground ice",
                                            "Massive ground ice")))
  ggplot(pan, aes(lon, lat, fill = value)) +
    geom_point(shape = 21, size = 1.5, stroke = .2, colour = "grey25") +
    facet_wrap(~panel, ncol = 2) +
    scale_fill_manual(values = c(Yes = YES_COL, No = NO_COL), name = NULL) +
    scale_x_continuous(breaks = seq(-161.85, -161.77, by = .04),
                       labels = function(x) sprintf("%.2f\u00b0W", abs(x))) +
    scale_y_continuous(breaks = seq(60.77, 60.81, by = .02),
                       labels = function(y) sprintf("%.2f\u00b0N", y)) +
    coord_fixed(ratio = 1 / cos(60.79 * pi / 180)) +
    labs(title = "Near-surface permafrost conditions, Bethel area",
         subtitle = sprintf(
           "%d borehole records synthesised from archived geotechnical reports",
           nrow(bh)),
         x = NULL, y = NULL, caption = "Data: doi:10.18739/A2P55DJ80") +
    theme_pg() +
    theme(panel.background = element_rect(fill = "grey97", colour = NA),
          panel.grid.major = element_line(colour = "grey90", linewidth = .25),
          axis.text = element_text(size = 7.5),
          panel.spacing.x = grid::unit(1.2, "lines"),
          strip.text = element_text(face = "bold", size = 10.5, colour = PG_GREEN),
          plot.caption = element_text(size = 8, colour = "#5b6770"))
}

#' Locate the most pronounced closed thaw hollow and return a short transect.
#'
#' The relief raster (terrain minus its own moving average) also lights up at
#' slope breaks and survey edges, so candidate cells are restricted to gently
#' sloping ground inside the survey before the minimum is taken.
pick_profile <- function(dtm, relief, slope, half_len_m = 100,
                         max_slope = 6, edge_buffer_m = 80) {
  # web-mercator metres per ground metre at this latitude
  y_mid   <- mean(c(ext(dtm)[3], ext(dtm)[4]))
  lat_deg <- (2 * atan(exp(y_mid / 6378137)) - pi / 2) * 180 / pi
  k       <- 1 / cos(lat_deg * pi / 180)

  cand <- relief
  cand[slope > max_slope] <- NA
  b  <- edge_buffer_m * k
  e  <- ext(dtm)
  cand <- crop(cand, ext(e[1] + b, e[2] - b, e[3] + b, e[4] - b))

  xy <- xyFromCell(cand, which.min(values(cand)))
  hl <- half_len_m * k
  xs <- seq(xy[1] - hl, xy[1] + hl, length.out = 600)
  prof <- data.frame(x    = xs,
                     elev = terra::extract(dtm,    cbind(xs, xy[2]))[, 1],
                     rel  = terra::extract(relief, cbind(xs, xy[2]))[, 1]) |>
    drop_na()
  prof$dist <- (prof$x - min(prof$x)) / k
  attr(prof, "centre") <- xy
  prof
}

#' West-east ground profile across the selected hollow
profile_plot <- function(prof) {
  low  <- prof[which.min(prof$rel), ]
  span <- diff(range(prof$elev))
  ggplot(prof, aes(dist, elev)) +
    geom_line(colour = PG_GREEN, linewidth = .7) +
    geom_point(data = low, colour = PG_GOLD, size = 2.8) +
    annotate("text", x = low$dist, y = low$elev - .10 * span,
             label = sprintf("floor of the hollow:\n%.1f m below the surrounding ground",
                             abs(low$rel)),
             size = 3.2, colour = PG_GOLD_DK, hjust = .5, vjust = 1) +
    labs(title = "West-east ground profile across a thaw hollow, 2023",
         subtitle = sprintf("%0.0f m transect through the drone lidar terrain model",
                            max(prof$dist)),
         x = "Distance along profile (m)", y = "Ground elevation (m)") +
    scale_y_continuous(breaks = pretty_breaks(5)) +
    coord_cartesian(ylim = c(min(prof$elev) - .55 * span,
                             max(prof$elev) + .10 * span)) +
    theme_pg()
}
