
rm(list=ls())
setwd("~/Dropbox/Works_in_progress/git_repos/suicide-pm") # this is the location of the cloned repository 
datadir = "~/Dropbox/suicide/main_2017/" # this is the location of the data released for replication of the paper 
shpdir = "~/Dropbox/suicide/raw_data/" # this is the location of the shapefiles for Chinese counties

### Packages
list.of.packages <- c("tidyverse", "haven", "sf", "sp", "rgdal", "lubridate", "dplyr","raster", 
                      "rgeos", "ggmap", "scales", "viridis", "gtable","grid","magritter","gridExtra")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
# Install missing packages 
if(length(new.packages)) install.packages(new.packages, repos = "http://cran.us.r-project.org")

# Load packages 
invisible(lapply(list.of.packages, library, character.only = TRUE))

sims <- read_dta(file.path(datadir,"lives_saved.dta"))

# keep relevant variables
sims <- sims %>% dplyr::select(dsp_code, week, year, month, code, provcode, provname, dspname, avpop_tot, lives_saved, lives_saved_tot)

# collapse to total lives saved over the period
sims_plot <- sims %>% group_by(dsp_code) %>% summarise(lives_saved_tot = last(lives_saved_tot))

# MAP SETUP  --------------------------------------------------------

china_shp <- st_read(file.path(shpdir, "china_fixed","chn_fixed.shp"), stringsAsFactors = FALSE)  
china_pro <- st_read(file.path(shpdir, "china_province","china_province.shp"), stringsAsFactors = FALSE)  
china_city <- st_read(file.path(shpdir,"china_city", "chn_city.shp"), stringsAsFactors = FALSE)  

china_shp_plot <- china_shp %>%
  mutate(ADMINCODE = as.numeric(ADMINCODE)) %>%
  left_join(sims_plot, by = c("ADMINCODE" = "dsp_code")) 
  
# MAP ================================================================

# simplify for testing
library("rmapshaper")
library("RColorBrewer")
simplepolys <- rmapshaper::ms_simplify(input = as(china_shp_plot, 'Spatial')) %>%
  st_as_sf()

mycolorvec = brewer.pal(11, "BrBG")
start = -55
end = 110

breaks <- c(-50, 0,50,100)

# crop extent (weird shapes blow 18N)
mycrop = function(shp) {
  out = st_crop(shp, xmin = 73.4, xmax = 135.1,
                ymin = 18.2, ymax = 53.6)
  return(out)
}

simple_crp = mycrop(simplepolys)
simple_pro = mycrop(china_pro)
simple_city = mycrop(china_city)

# continues scale
ggplot() +
  #geom_sf(data = china_shp_plot, aes(fill = lives_saved_tot), color = NA) +
  geom_sf(data = simple_crp, aes(fill = lives_saved_tot), color = NA) +
  geom_sf(data = simple_pro, fill = NA, color = alpha("gray40", 1 / 2), size = 0.3) +
  geom_sf(data = simple_city, fill = NA, color = alpha("gray40", 1 / 2), size = 0.1) +
  scale_fill_gradientn(colors = mycolorvec,
                       values=rescale(c(start, start/2, 0, end/10, end)),
                       limits = c(start, end),
                       na.value = "grey70",
                       breaks = breaks,
                       guide = guide_colorbar(
                         direction = "horizontal",
                         barheight = unit(2, units = "mm"),
                         barwidth = unit(50, units = "mm"),
                         draw.ulim = F,
                         title.position = 'top',
                         # some shifting around
                         title.hjust = 0.5,
                         label.hjust = 0.5
                       )) +
  
  labs(fill = "Avoided suicides",
       title = "Suicide deaths avoided due to pollution declines",
       subtitle = "2013 ~ 2017") +
  theme(panel.grid.major = element_blank(), 
        panel.grid.minor = element_blank(),
        panel.background = element_blank(),
        plot.title = element_text(size = 16),
        plot.subtitle = element_text(size = 12),
        axis.ticks = element_blank(),
        axis.text = element_blank(),
        legend.position = "bottom") ; ggsave(file.path("results", "figures", "fig3C_avoided_deaths_map.png"), width = 20, height = 20, units = "cm")

# 
# 
#   #scale_colour_gradient2(low = mycolorvec[1], mid = mycolorvec[6], high = mycolorvec[11], midpoint = 0, breaks = breaks)
#   
#   ggplot() +
#     #geom_sf(data = china_shp_plot, aes(fill = lives_saved_tot), color = NA) +
#     geom_sf(data = simplepolys, aes(fill = lives_saved_tot), color = NA) +
#     #geom_sf(data = china_pro, fill = NA, color = "white", size = 0.3) +
#     #geom_sf(data = china_city, fill = NA, color = alpha("white", 1 / 2), size = 0.1) +
#     
#     scale_fill_gradient2(low = "#543005", mid = "#F5F5F5", high = "#003C30", midpoint = 0, breaks = breaks,
#                          limits = c(start,end),
#                          na.value = "grey70")
#   
# 
# ## SCRAP
#   # continues scale
# ggplot() +
#   #geom_sf(data = china_shp_plot, aes(fill = lives_saved_tot), color = NA) +
#   geom_sf(data = simplepolys, aes(fill = lives_saved_tot), color = NA) +
#   #geom_sf(data = china_pro, fill = NA, color = "white", size = 0.3) +
#   #geom_sf(data = china_city, fill = NA, color = alpha("white", 1 / 2), size = 0.1) +
#   
#   scale_fill_brewer(palette = "BrBG", direction = -1, na.value="grey70", 
#                        limits = c(-50, 110), oob = squish,
#                        guide = guide_colorbar(
#                          direction = "horizontal",
#                          barheight = unit(2, units = "mm"),
#                          barwidth = unit(50, units = "mm"),
#                          draw.ulim = F,
#                          title.position = 'top',
#                          # some shifting around
#                          title.hjust = 0.5,
#                          label.hjust = 0.5
#                        )) +  
#   scale_y_continuous(limits = c(-50,110)) 
# 
# 
# 
# +
#   
#   labs(fill = "Avoided suicides",
#        title = "Suicide deaths avoided due to pollution declines",
#        subtitle = "2013 ~ 2017") +
#   
#   theme(panel.grid.major = element_blank(), 
#         panel.grid.minor = element_blank(),
#         panel.background = element_blank(),
#         plot.title = element_text(size = 20),
#         plot.subtitle = element_text(size = 15),
#         axis.ticks = element_blank(),
#         axis.text = element_blank(),
#         legend.position = "bottom") 
# 
# ; ggsave(file.path("results", "figures", "fig3C_avoided_deaths_map.png"), width = 20, height = 20, units = "cm")
# 

  