# ---------------------------------------------------------------------------
# Prepare derived layers for the Permafrost Grown Year 3 dashboard
#   Bethel boreholes  : doi:10.18739/A2P55DJ80
#   Midnight Sun GC   : doi:10.18739/A2W37KX40
# ---------------------------------------------------------------------------
suppressPackageStartupMessages({
  library(terra); library(sf); library(dplyr); library(readr)
  library(stringr); library(tidyr)
})
out <- "dashboard/data"; dir.create(out, showWarnings = FALSE, recursive = TRUE)

## ---- 1. Bethel boreholes --------------------------------------------------
bh <- read_csv("data/Bethel_Geotechnical_Reports_Boreholes.csv", show_col_types = FALSE)
yn   <- function(x) factor(ifelse(x == 1, "Yes", "No"), levels = c("Yes", "No"))
na999 <- function(x) ifelse(!is.na(x) & x >= 999, NA_real_, x)

bh2 <- bh |>
  mutate(
    permafrost    = yn(Permafrost_Presence),
    talik         = yn(Talik_Presence),
    visible_ice   = yn(Visible_Ice_Presence),
    massive_ice   = yn(Massive_Ice_Presence),
    drill_date    = suppressWarnings(as.Date(Drilling_D, format = "%m/%d/%Y")),
    report_year   = as.integer(Report_Yea),
    drill_year    = as.integer(format(drill_date, "%Y")),
    depth_m       = as.numeric(Borehole_Depth_m),
    pf_top_m      = na999(suppressWarnings(as.numeric(Frozen_Ground_Depth_Top))),
    pf_bottom_raw = as.character(Frozen_Ground_Depth_Bottom),
    pf_bottom_m   = na999(suppressWarnings(as.numeric(pf_bottom_raw))),
    # ">" in the source table means the borehole ended while still in frozen ground
    pf_base_not_reached = str_detect(replace_na(pf_bottom_raw, ""), ">")
  ) |>
  rename(site_id = Site_ID, lat = Latitude, lon = Longitude, agency = Agency,
         report = Report_Nam, project_no = Project_No, borehole_id = Borehole_I)

keep <- c("site_id","borehole_id","lat","lon","agency","report","report_year",
          "drill_date","drill_year","depth_m","pf_top_m","pf_bottom_m",
          "pf_base_not_reached","permafrost","talik","visible_ice","massive_ice")
bh_out <- bh2[, keep]
write_csv(bh_out, file.path(out, "bethel_boreholes.csv"))
st_write(st_as_sf(bh_out, coords = c("lon","lat"), crs = 4326, remove = FALSE),
         file.path(out, "bethel_boreholes.gpkg"), delete_dsn = TRUE, quiet = TRUE)

cat("BETHEL  n =", nrow(bh_out),
    "| reports:", n_distinct(bh_out$report),
    "| report yrs:", min(bh_out$report_year), "-", max(bh_out$report_year),
    "| drill yrs:", min(bh_out$drill_year, na.rm=TRUE), "-", max(bh_out$drill_year, na.rm=TRUE), "\n")
cat("  permafrost Yes:", sum(bh_out$permafrost=="Yes"),
    "| talik Yes:", sum(bh_out$talik=="Yes"),
    "| visible ice Yes:", sum(bh_out$visible_ice=="Yes"),
    "| massive ice Yes:", sum(bh_out$massive_ice=="Yes"), "\n")
cat("  pf_top_m median:", round(median(bh_out$pf_top_m, na.rm=TRUE),2),
    "| n with pf_top:", sum(!is.na(bh_out$pf_top_m)),
    "| base not reached:", sum(bh_out$pf_base_not_reached), "\n")
cat("  depth_m max:", max(bh_out$depth_m), "| median:", median(bh_out$depth_m), "\n")

## ---- 2. Midnight Sun Golf Course 2023 drone terrain ------------------------
dtm <- rast("data/msgc_dtm_2023.tif")
names(dtm) <- "elev"

# 1 m working grid (0.25 m source is far more detail than a web map needs)
dtm1 <- aggregate(dtm, fact = 4, fun = "mean", na.rm = TRUE)

# Local relief: ground height relative to a 60 m moving average. Thermokarst
# pits, troughs and the collapsed former field read as negative values.
bg     <- focal(dtm1, w = 61, fun = "mean", na.rm = TRUE, expand = TRUE)
relief <- dtm1 - bg
names(relief) <- "relief"

hs <- shade(terrain(dtm1, "slope",  unit = "radians"),
            terrain(dtm1, "aspect", unit = "radians"),
            angle = 35, direction = 315)
names(hs) <- "hillshade"

web <- function(r, method) project(r, "EPSG:3857", method = method)
writeRaster(web(dtm1,   "bilinear"), file.path(out, "msgc_dtm_1m_web.tif"),
            overwrite = TRUE, gdal = c("COMPRESS=DEFLATE","PREDICTOR=3"))
writeRaster(web(relief, "bilinear"), file.path(out, "msgc_relief_1m_web.tif"),
            overwrite = TRUE, gdal = c("COMPRESS=DEFLATE","PREDICTOR=3"))
writeRaster(web(hs,     "bilinear"), file.path(out, "msgc_hillshade_1m_web.tif"),
            overwrite = TRUE, gdal = c("COMPRESS=DEFLATE","PREDICTOR=3"))

# actual data coverage (the survey is L-shaped, not the full rectangle)
cov  <- aggregate(!is.na(dtm1), fact = 10, fun = "max", na.rm = TRUE)
foot <- as.polygons(cov) |> st_as_sf()
foot <- foot[foot[[1]] == 1, ] |> st_union() |> st_transform(4326) |> st_sf()
st_write(foot, file.path(out, "msgc_footprint.gpkg"), delete_dsn = TRUE, quiet = TRUE)

# slope, used to keep profile picking off steep slope breaks
slp <- terrain(dtm1, "slope", unit = "degrees")
writeRaster(project(slp, "EPSG:3857", method = "bilinear"),
            file.path(out, "msgc_slope_1m_web.tif"),
            overwrite = TRUE, gdal = c("COMPRESS=DEFLATE","PREDICTOR=3"))

rv <- values(relief, na.rm = TRUE)
cat("MSGC    cells:", ncell(dtm1), "| elev range:", round(minmax(dtm1)[1],1), "-",
    round(minmax(dtm1)[2],1), "m\n")
cat("  footprint:", round(diff(ext(dtm)[1:2])), "x", round(diff(ext(dtm)[3:4])), "m =",
    round(prod(diff(ext(dtm)[1:2]), diff(ext(dtm)[3:4]))/1e4, 1), "ha\n")
cat("  local relief range:", round(min(rv),2), "to", round(max(rv),2),
    "m | 1st pct:", round(quantile(rv, 0.01),2), "| 99th pct:", round(quantile(rv, 0.99),2), "\n")
cat("  area >0.5 m below local average:", round(sum(rv < -0.5)/length(rv)*100, 1), "%\n")
cat("done\n")
