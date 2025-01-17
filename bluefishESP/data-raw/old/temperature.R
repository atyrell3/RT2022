`%>%` <- magrittr::`%>%`

# shapefile setup
crs <- "+proj=longlat +datum=WGS84 +no_defs +ellps=WGS84 +towgs84=0,0,0"

# different geom fix
sf::sf_use_s2(FALSE)

geom <- NEesp::shape %>%
  dplyr::select(STRATA, geometry) %>%
  sf::st_transform(proj4string = crs) %>%
  # try geom fix?
  # dplyr::mutate(geometry = geometry %>%
  #                 s2::s2_rebuild() %>%
  #                 sf::st_as_sfc()) %>%
  dplyr::summarise(geometry = sf::st_union(geometry)) %>%
  sf::st_crop(y = c(xmin = -80, xmax = -69,
                    ymax = 41.5, ymin =  35.8327))

years <- 1982:2021
first <- c()
last <- c()
n_days <- c()
for(j in years) {
  message(paste("starting", j))
  # download data ----
  dir.create(here::here("data-raw","gridded", "sst_data"), recursive = TRUE)
  url <- paste0("https://downloads.psl.noaa.gov/Datasets/noaa.oisst.v2.highres/sst.day.mean.", j, ".v2.nc")
  download.file(url, destfile = "test.nc")

  # R can't open the file (will have to do this in a gh action...)
  # download file manually for testing on desktop

  # name <- paste0(j, ".nc")
  name <- "test.nc"

  data <- ecopull::nc_to_raster(nc = name, varname = 'sst')
  data <- raster::rotate(data)
  message("converted to raster...")

  # make sure all days are there ----

  if(raster::nlayers(data) < 365) {
    message(j, " does not have a full year of data! skipping!")
  } else {

  # crop to MAB ----
  ndays <- raster::nlayers(data) # account for leap years

  mab_temp <- raster::mask(x = data[[1:180]],
                           mask = geom)
  mab_temp2 <- raster::mask(x = data[[181:ndays]],
                            mask = geom)
  message("cropped to MAB...")

  # create dataframes ----
  rast_mab_df <- raster::as.data.frame(mab_temp, xy = TRUE)
  rast_mab_df2 <- raster::as.data.frame(mab_temp2, xy = TRUE)
  message("created data frames...")

  # calculate mean temperature by day ----
  mab_df<- data.frame()
  for(i in 1:raster::nlayers(mab_temp)){
    names <- mab_temp[[i]]@data@names
    mean_temp <- mean(mab_temp[[i]]@data@values, na.rm = TRUE)
    min_temp <- mab_temp[[i]]@data@min
    max_temp <- mab_temp[[i]]@data@max

    dat<-cbind(names, mean_temp, min_temp, max_temp)
    mab_df<-rbind(mab_df, dat)
  }

  mab_df2 <- data.frame()
  for(i in 1:raster::nlayers(mab_temp2)){
    names <- mab_temp2[[i]]@data@names
    mean_temp <- mean(mab_temp2[[i]]@data@values, na.rm = TRUE)
    min_temp <- mab_temp2[[i]]@data@min
    max_temp <- mab_temp2[[i]]@data@max

    dat<-cbind(names, mean_temp, min_temp, max_temp)
    mab_df2<-rbind(mab_df2, dat)
  }

  all_df <- rbind(mab_df,
                  mab_df2) %>%
    dplyr::mutate(Year = stringr::str_extract(names, pattern = "\\d{4}"),
                  names = stringr::str_remove(names, pattern = "X"),
                  DOY = lubridate::as_date(names),
                  week = lubridate::week(DOY),
                  mean_temp = as.numeric(mean_temp))

  this_first <- all_df %>%
    dplyr::filter(mean_temp >= 18) %>%
    dplyr::arrange(DOY)

  first <- c(first, lubridate::yday(this_first$DOY[1]))
  last <- c(last, lubridate::yday(this_first$DOY[nrow(this_first)]))
  message("calculated mean temp...")

  # calculate proportion above 18C by day ----
  names <- c()
  value <- c()
  for(i in 3:ncol(rast_mab_df)){
    new_dat <- rast_mab_df[,i] %>%
      tibble::as_tibble() %>%
      tidyr::drop_na()
    names[i-2] <- colnames(rast_mab_df[i])
    value[i-2] <- nrow(new_dat %>% dplyr::filter(value > 18)) / nrow(new_dat)
  }
  mab_prop <- tibble::tibble(names, value, region = "MAB")

  names <- c()
  value <- c()
  for(i in 3:ncol(rast_mab_df2)){
    new_dat <- rast_mab_df2[,i] %>%
      tibble::as_tibble() %>%
      tidyr::drop_na()
    names[i-2] <- colnames(rast_mab_df2[i])
    value[i-2] <- nrow(new_dat %>% dplyr::filter(value > 18)) / nrow(new_dat)
  }
  mab_prop2 <- tibble::tibble(names, value, region = "MAB")

  mab_prop <- rbind(mab_prop, mab_prop2) %>%
    dplyr::mutate(Year = stringr::str_extract(names, pattern = "\\d{4}"),
                  names = stringr::str_remove(names, pattern = "X"),
                  DOY = lubridate::as_date(names),
                  week = lubridate::week(DOY),
                  value = as.numeric(value))

  this_n_days <- mab_prop %>%
    dplyr::filter(region == "MAB",
                  value >= 0.75) %>%
    dplyr::arrange(DOY)

  n_days <- c(n_days, length(this_n_days$DOY))
  message("calculated proportion...")
  }
  message(paste("done with", j))
}

first
last
n_days

out_data <- tibble::tibble(years, first, last, n_days)
write.csv(out_data, here::here("data-raw/temperature_indicators.csv"))
