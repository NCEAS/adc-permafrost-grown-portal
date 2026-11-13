# Permafrost Grown — Year 3 Highlights dashboard

An interactive Quarto dashboard that presents the content of the printed
*Permafrost Grown Year 3 Highlights* flyer, with the underlying Arctic Data Center
datasets made explorable for a non-specialist audience (farmers, landowners, city and
borough planners).

Rendered dashboard: [index.html]({{artifact:03cb5a76-8c06-4424-8da1-bfa261090b11}}) —
one self-contained HTML file. Basemap tiles load from Esri at view time; everything
else is embedded.

## Pages

| Page | Content |
| --- | --- |
| Overview | Project framing, headline numbers, locator map of the two study areas |
| Thaw subsidence | Interactive 2023 drone lidar terrain map of Midnight Sun Golf Course, Fairbanks, plus a ground profile across a thaw hollow |
| Bethel ice wedges | Interactive borehole map with four switchable indicators, summary charts |
| The borehole records | Searchable, sortable, downloadable table of all 762 records |
| Working with farmers | Engagement narrative, practical guidance, project publications |
| Data & methods | Data sources with DOIs and how each derived layer was made |

## Data sources

Both datasets are published openly on the Arctic Data Center.

1. **Midnight Sun Golf Course Classified LiDAR Point Cloud, Digital Surface Model,
   Digital Terrain Model, Digital Photos, and Orthophoto Mosaic** (10 September 2023) —
   [doi:10.18739/A2W37KX40](https://doi.org/10.18739/A2W37KX40).
   Files used: the 25 cm digital terrain model and its hillshade. The 29 GB point cloud
   and 1.1 GB orthomosaic in the same package are not needed by the dashboard.
2. **Synthesis of near-surface permafrost borehole information from Bethel Geotechnical
   Reports (1967–2004)** —
   [doi:10.18739/A2P55DJ80](https://doi.org/10.18739/A2P55DJ80).
   File used: `Bethel_Geotechnical_Reports_Boreholes.csv` (762 records).

## Important: the first graphic is not reproduced

The printed flyer's first graphic is a **2017→2023 elevation-difference map**, produced
by differencing Fairbanks North Star Borough lidar flown in 2017 against the 2023 drone
survey. The 2017 survey is **not** part of doi:10.18739/A2W37KX40, so this dashboard
does not recompute that change map.

Instead the Thaw subsidence page shows the **2023** surface directly: a shaded relief
layer and a "low ground" layer (the terrain model minus its own 61 m moving average),
which makes the thermokarst pits, troughs and collapsed hollows visible without
inventing a change signal. The *up to 1.5 m of thaw subsidence, 2017–2023* figure is
carried through as the project's own published result and is labelled as such.

A public 2017 surface does exist — the USGS 3DEP product
`AK_Fairbanks_NSB_Lidar_2017_B17` (QL1 point cloud, five tiles cover the site). If you
later want the change map rebuilt from it, note that the two surveys use different
vertical references (2023 is WGS84 ellipsoid height; 3DEP is NAVD88), so they must be
co-registered over stable ground before differencing.

## Layout of this bundle

```
dashboard/
  index.qmd              dashboard source (Quarto, knitr/R engine)
  custom.scss            theme
  R/panels.R             shared palettes, ggplot theme, plot builders
  data/                  derived layers consumed by the dashboard
  figures/               static companion PNGs
  index.html             rendered output
scripts/
  prep_data.R            downloads-to-derived-layers step (run first)
  make_figures.R         static companion figures
  check_html.py          structural smoke test on the rendered HTML
quartoenv.sh             sets QUARTO_* paths when Quarto comes from conda
```

## Derived layers

| File | How it was made |
| --- | --- |
| `msgc_dtm_1m_web.tif` | Published 25 cm terrain model averaged to 1 m, reprojected to EPSG:3857 |
| `msgc_hillshade_1m_web.tif` | Hillshade of that 1 m model, sun altitude 35°, azimuth 315° |
| `msgc_relief_1m_web.tif` | 1 m model minus its own 61 m moving average; negative = below the local average surface |
| `msgc_slope_1m_web.tif` | Slope in degrees, used to keep the profile transect off slope breaks |
| `msgc_footprint.gpkg` | Actual data coverage polygon (the survey is L-shaped, ~75 ha) |
| `bethel_boreholes.csv/.gpkg` | Published borehole table with the four 0/1 indicators recoded to Yes/No, `999` recoded to missing per the dataset's EML missing-value codes, and `>` in the frozen-ground base column flagged as `pf_base_not_reached` |

## Rebuilding

Requires R (terra, sf, leaflet, DT, ggplot2, dplyr, readr, tidyr, scales, htmltools)
and Quarto ≥ 1.4. The two source files must be present in `data/`
(`Bethel_Geotechnical_Reports_Boreholes.csv`, `msgc_dtm_2023.tif`,
`msgc_hillshade_2023.tif`), downloaded from the DOIs above.

```sh
Rscript scripts/prep_data.R      # build derived layers in dashboard/data/
Rscript scripts/make_figures.R   # build static PNGs in dashboard/figures/
quarto render dashboard/index.qmd
```

If Quarto is installed through conda, `source quartoenv.sh` first so it can find its
bundled deno, pandoc and dart-sass.

## Publishing

`index.html` is self-contained, so it can be emailed, dropped on a web server, or
published with `quarto publish gh-pages`. The only runtime network calls are Esri
basemap tiles; without a connection the maps still draw their data layers on a blank
background.
