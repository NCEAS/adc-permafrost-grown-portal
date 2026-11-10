# Static companion figures for the Permafrost Grown Year 3 dashboard
suppressPackageStartupMessages({library(readr)})
source("dashboard/R/panels.R")
fig <- "dashboard/figures"; dir.create(fig, showWarnings = FALSE, recursive = TRUE)

bh <- read_csv("dashboard/data/bethel_boreholes.csv", show_col_types = FALSE) |>
  mutate(across(c(permafrost, talik, visible_ice, massive_ice),
                ~factor(.x, levels = c("Yes", "No"))))

## --- 1. Bethel four-panel map ---------------------------------------------
ggsave(file.path(fig, "fig_bethel_panels.png"), panel_map(bh),
       width = 9.5, height = 8.4, dpi = 200)

## --- 2. Indicator summary bar ---------------------------------------------
ggsave(file.path(fig, "fig_bethel_indicators.png"), indicator_plot(bh),
       width = 7.2, height = 3.4, dpi = 200)

## --- 3. Depth to frozen ground --------------------------------------------
ggsave(file.path(fig, "fig_bethel_depth.png"), depth_plot(bh),
       width = 7.2, height = 3.6, dpi = 200)

## --- 4. Midnight Sun terrain map ------------------------------------------
dtm  <- rast("dashboard/data/msgc_dtm_1m_web.tif")
rel  <- rast("dashboard/data/msgc_relief_1m_web.tif")
hs   <- rast("dashboard/data/msgc_hillshade_1m_web.tif")
slp  <- rast("dashboard/data/msgc_slope_1m_web.tif")
prof <- pick_profile(dtm, rel, slp)
ctr  <- attr(prof, "centre")

png(file.path(fig, "fig_msgc_terrain.png"), width = 1900, height = 1400, res = 170)
par(mar = c(3.4, 2, 3.2, 1))
plot(hs, col = grey.colors(64, start = .12, end = .98), legend = FALSE,
     axes = FALSE, mar = c(3.4, 2, 3.2, 7),
     main = "Midnight Sun Golf Course: 2023 drone lidar ground surface")
plot(clamp(rel, -1.5, 1.5, values = TRUE), add = TRUE, alpha = .62,
     col = rev(colorRampPalette(c("#67001f", "#d6604d", "#f7f7f7",
                                  "#92c5de", "#2166ac"))(64)),
     range = c(-1.5, 1.5),
     plg = list(title = "Height relative\nto surrounding\nground (m)", cex = .8))
segments(min(prof$x), ctr[2], max(prof$x), ctr[2], col = "#c9892b", lwd = 2.5)
points(ctr[1], ctr[2], pch = 21, bg = "#c9892b", col = "white", cex = 1.1)
mtext(paste("Blue = ground sitting below the local average surface (thaw hollows,",
            "troughs).  Gold line = profile below.  Data doi:10.18739/A2W37KX40"),
      side = 1, line = 1.2, cex = .72, col = "#5b6770")
dev.off()

## --- 5. Terrain profile ----------------------------------------------------
ggsave(file.path(fig, "fig_msgc_profile.png"), profile_plot(prof),
       width = 7.5, height = 3.6, dpi = 200)

low <- prof[which.min(prof$rel), ]
cat("profile centre (web-mercator):", round(ctr), "\n")
cat("hollow floor:", round(low$rel, 2), "m below surroundings; elevation range",
    round(range(prof$elev), 1), "m over", round(max(prof$dist)), "m\n")
cat("figures written to", fig, "\n")
