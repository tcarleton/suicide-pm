
rm(list=ls())
setwd("~/Dropbox/Works_in_progress/git_repos/suicide-pm") # this is the location of the cloned repository 
datadir = "~/Dropbox/suicide/main_2017/" # this is the location of the data released for replication of the paper 
shpdir = "~/Dropbox/suicide/raw_data" # this is the location of the shapefiles for Chinese counties

### Packages
list.of.packages <- c("tidyverse", "haven", "sf", "sp", "rgdal", "lubridate", "dplyr","raster", 
                      "rgeos", "ggmap", "scales", "viridis", "gtable","grid","gridExtra")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
# Install missing packages 
if(length(new.packages)) install.packages(new.packages, repos = "http://cran.us.r-project.org")

# Load packages 
invisible(lapply(list.of.packages, library, character.only = TRUE))

pollution <- read_dta(file.path(datadir,"pollution_county_daily_2013_2018.dta"))

# SECTION I: COUNTY TREND COEFFICIENTS --------------------------------------------------------
  
# remove 2018 as it is not used in our estimation sample in estimating the suicide-PM relationship
pollution <- pollution %>% filter(year<2018)

 # day of sample 
pollution <- pollution %>% 
  mutate(datevar = paste0(year,"-", month, "-",day)) %>%
  mutate(datevar = as.Date(datevar)) 

china_pollution <- data.frame(matrix(nrow = 0, ncol = 0))

for (i in seq_along(unique(pollution$county_id))){
  tryCatch({
  
  pollution_county <- pollution %>% filter(county_id == unique(pollution$county_id)[i])
  #pm25 average
  mean_pm25 <- pollution_county %>% pull(pm25) %>% mean(na.rm = TRUE)
  #pm25 coeff, se, pvalue
  coeff_pm25 <- lm(pm25~datevar, pollution_county) %>% summary() %>% {.$coefficients} %>% {.[2,1]}
  se_pm25 <- lm(pm25~datevar, pollution_county) %>% summary() %>% {.$coefficients} %>% {.[2,2]}
  pvalue_pm25 <- lm(pm25~datevar, pollution_county) %>% summary() %>% {.$coefficients} %>% {.[2,4]}
  
  #pm10 average
  mean_pm10 <- pollution_county %>% pull(pm10) %>% mean(na.rm = TRUE)
  #pm10 coeff, se, pvalue
  coeff_pm10 <- lm(pm10~datevar, pollution_county) %>% summary() %>% {.$coefficients} %>% {.[2,1]}
  se_pm10 <- lm(pm10~datevar, pollution_county) %>% summary() %>% {.$coefficients} %>% {.[2,2]}
  pvalue_pm10 <- lm(pm10~datevar, pollution_county) %>% summary() %>% {.$coefficients} %>% {.[2,4]}
  
  
  #aqi average
  mean_aqi <- pollution_county %>% pull(aqi) %>% mean(na.rm = TRUE)
  #aqi coeff, se, pvalue
  coeff_aqi <- lm(aqi~datevar, pollution_county) %>% summary() %>% {.$coefficients} %>% {.[2,1]}
  se_aqi <- lm(aqi~datevar, pollution_county) %>% summary() %>% {.$coefficients} %>% {.[2,2]}
  pvalue_aqi <- lm(aqi~datevar, pollution_county) %>% summary() %>% {.$coefficients} %>% {.[2,4]}
  
  county_id <- unique(pollution$county_id)[i]
  results_county <- data.frame(county_id, 
                               mean_pm25, coeff_pm25, se_pm25, pvalue_pm25,
                               mean_pm10, coeff_pm10, se_pm10, pvalue_pm10,
                               mean_aqi, coeff_aqi, se_aqi, pvalue_aqi)
  
  china_pollution <- bind_rows(china_pollution, results_county)
  
  print(paste0("-------- Done with county ",unique(pollution$county_id)[i], " in ", i, " of ", length(unique(pollution$county_id))))
  }, error = function(e){cat("Error:", conditionMessage(e), '\n')})
}


write.csv(china_pollution, file.path(datadir,"chn_pollution.csv"), row.names = FALSE)


# SECTION II: POLLUTION AVERAGE MAP --------------------------------------------------------

china_pollution <- read.csv(file.path(datadir,"chn_pollution.csv"))
china_shp <- st_read(file.path(shpdir, "china_fixed_updated","china__fixed","china__fixed.shp"), stringsAsFactors = FALSE)  
china_pro <- st_read(file.path(shpdir, "china_province_updated","china__province", "china_province.shp"), stringsAsFactors = FALSE)  
china_city <- st_read(file.path(shpdir,"china_city_updated", "china__city","china_city.shp"), stringsAsFactors = FALSE)  

china_shp_plot <- china_shp %>%
  mutate(ADMINCODE = as.numeric(ADMINCODE)) %>%
  left_join(china_pollution, by = c("ADMINCODE" = "county_id")) 


  # COUNTY AVERAGE PM 2.5 ================================================================

  # continues scale
ggplot() +
  geom_sf(data = china_shp_plot, aes(fill = mean_pm25), color = NA) +
  geom_sf(data = china_pro, fill = NA, color = "white", size = 0.3) +
  geom_sf(data = china_city, fill = NA, color = alpha("white", 1 / 2), size = 0.1) +
  

  scale_fill_viridis(option = "magma", direction = -1, na.value="grey70", 
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
  scale_color_viridis(option = "magma", direction = -1, guide = "none", na.value="grey70") +  

  scale_y_continuous(limits = c(20,55)) +
  
  labs(fill = "Average PM 2.5",
       title = "China's regional demographics",
       subtitle = "County Average PM 2.5, 2013 ~ 2017") +
  
  theme(panel.grid.major = element_blank(), 
        panel.grid.minor = element_blank(),
        panel.background = element_blank(),
        plot.title = element_text(size = 20),
        plot.subtitle = element_text(size = 15),
        axis.ticks = element_blank(),
        axis.text = element_blank(),
        legend.position = "bottom"); ggsave(file.path("results", "figures", "appendix", "average_pm25.pdf"), width = 20, height = 20, units = "cm")


  # COUNTY AVERAGE  AQI AND PM 10 ========================================================
  
  # NOTE: the following code will produce an AQI map
  #       if you want to create the the pm10 map, change the plot title and fill = mean_aqi to mean_pm10

ggplot() +
  geom_sf(data = china_shp_plot, aes(fill = mean_aqi), color = NA) +
  geom_sf(data = china_pro, fill = NA, color = "white", size = 0.3) +
  geom_sf(data = china_city, fill = NA, color = alpha("white", 1 / 2), size = 0.1) +
  
  
  scale_fill_viridis(option = "magma", direction = -1, na.value="grey70",  
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
  scale_color_viridis(option = "magma", direction = -1, guide = "none", na.value="grey70") +  
  
  scale_y_continuous(limits = c(20,55)) +
  
  labs(fill = "Average Air Quality Index",
       title = "China's regional demographics",
       subtitle = "County Average Air Quality Index, 2013 ~ 2017") +
  
  theme(panel.grid.major = element_blank(), 
        panel.grid.minor = element_blank(),
        panel.background = element_blank(),
        plot.title = element_text(size = 20),
        plot.subtitle = element_text(size = 15),
        axis.ticks = element_blank(),
        axis.text = element_blank(),
        legend.position = "bottom"); ggsave(file.path("results", "figures", "appendix","average_aqi.pdf"), width = 20, height = 20, units = "cm")


# SECTION III: POLLUTION COUNTY TREND MAP --------------------------------------------------------

china_shp_plot <- china_shp %>%
  mutate(ADMINCODE = as.numeric(ADMINCODE)) %>%
  left_join(china_pollution, by = c("ADMINCODE" = "county_id"))  %>% 
  dplyr::select(ADMINCODE, coeff_pm10, coeff_pm25, coeff_aqi) %>%
  gather(key = "indicator", value = "coef", -c(ADMINCODE, geometry)) %>%
  mutate(indicator = sub("coeff_", "", indicator))

  # NOTE: the following code creates a dummy variable for significance level threshold 0.05
  #       skip if you do not want outline counties by coefficient significance level 
# 
# pm_25sig <- china_shp_plot %>%
#   mutate(province = gsub("....$", "", ADMINCODE))
# 
# df <- pm_25sig %>% dplyr::select(province)
# df$geometry <- NULL
# 
# spdf <- pm_25sig$geometry %>% as_Spatial()
# pm_25sig_pro <- SpatialPolygonsDataFrame(spdf, df, match.ID = FALSE)
# pm_25sig_pro_agg<- raster::aggregate(pm_25sig_pro, by = "province")
# pm_25sig_pro_st <- pm_25sig_pro_agg %>% st_as_sf()

# only want coefficient on pm25
china_shp_plot = china_shp_plot %>% filter(indicator=="pm25")

# convert trends to per year (from per day)
china_shp_plot$coef = china_shp_plot$coef*365

# simplify geometries  
simplepolys <- rmapshaper::ms_simplify(input = as(china_shp_plot, 'Spatial')) %>%
  st_as_sf()

ggplot() +
  geom_sf(data = simplepolys, aes(fill = coef), color = NA) +
  geom_sf(data = china_pro, fill = NA, color = "gray40", size = 0.3) +
  geom_sf(data = china_city, fill = NA, color = alpha("gray40", 1 / 2), size = 0.1) +
  
  # NOTE: comment the following if you want to outline counties by coefficient significance level 
  #geom_sf(data = pm_25sig_pro_st, fill = NA,color = alpha("gold4", 0.5), size = 0.5) +

  scale_fill_distiller(palette = "RdBu", direction = - 1, na.value="grey70", 
                       limits = c(-12, 12), oob = squish,
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
  
  #scale_y_continuous(limits = c(20,55)) +
  
  labs(fill = expression(paste(mu,'g/',m^3,' per year')),
       title = "Changes in county-level pollution",
       subtitle = "Trend in PM2.5, 2013 ~ 2017") +
  
  theme(panel.grid.major = element_blank(), 
        panel.grid.minor = element_blank(),
        panel.background = element_blank(),
        plot.title = element_text(size = 20, hjust = 0.5),
        plot.subtitle = element_text(size = 15, hjust = 0.5),
        axis.ticks = element_blank(),
        axis.text = element_blank(),
        legend.position = "bottom",
        strip.background = element_rect(fill="white", size=1.5),
        strip.text.x = element_text(size = 10)); ggsave(file.path("results","figures","Figure_1A_PMmap.png"), width = 20, height = 20, units = "cm")
