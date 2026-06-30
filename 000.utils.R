## 
# @author: Deng Chijun
# @desc: Custom R code for surface visualization 
##

list.of.packages <- c("ggseg", "ggplot2", "ggsci", "dplyr")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
lapply(list.of.packages, require, character.only = TRUE)


#-------------------------------------------------------------------- DK surface plot -------------------------------------------------------------------- 
PlotDK <- function(tvals, hemisphere = c("left", "right"), vmin = NULL, vmax = NULL, sym_bar=FALSE,
                   fill = NULL, palette = "PRGn", direction = -1, alpha = 1,
                   cmap = c('#81adcf','white','#ab90bd'), center = 0,
                   title = NULL, savedir = NULL) {
  
  # Load DK labels
  dk_labels <- read.csv('/Users/miaolab/Desktop/dengchijun/resources/atlas/dk/dk_atlas_info.csv')
  
  # Create data frame
  df <- data.frame(
    label = dk_labels$hemi_label,
    tval = as.numeric(tvals)
  )
  
  # if plot symmetric cbar
  if (sym_bar){
    bound = max(abs(as.numeric(tvals)))
    vmin = -1 * bound
    vmax = bound
  }
  
  # Base plot
  ax <- ggseg(.data = df, atlas = dk, mapping = aes(fill = tval),
              position = 'stacked', color = 'white', size = 0.1) +
    theme_void() + labs(fill = fill, title = title) +
    theme(axis.text = element_blank(), axis.title = element_blank())
  
  # Apply alpha to color scales and na.value
  if (!any(is.null(cmap)) && length(cmap) == 3) {
    cmap_adjusted <- scales::alpha(cmap, alpha = alpha)
    ax <- ax + scale_fill_gradient2(
      low = cmap_adjusted[1],
      mid = cmap_adjusted[2],
      high = cmap_adjusted[3],
      midpoint = center,
      limits = c(vmin, vmax),
      na.value = "grey90"
    )
  } else {
    pal <- RColorBrewer::brewer.pal(11, palette)
    if (direction == -1) pal <- rev(pal)
    pal_adjusted <- scales::alpha(pal, alpha = alpha)
    ax <- ax + scale_fill_gradientn(
      colors = pal_adjusted,
      limits = c(vmin, vmax),
      na.value = "grey90"
    )
  }
  
  if (!is.null(savedir)) {
    ggsave(savedir, plot = ax, dpi = 600, width = 3, height = 1.5, bg = "transparent")
  } else {
    print(ax)
  }
}

#-------------------------------------------------------------------- END -------------------------------------------------------------------- 

#-------------------------------------------------------------------- COLORMAPS -------------------------------------------------------------------- 

GetCmap <- function(cmap) {
  colors <- list(
    'c1'  = c('#84accf', 'white', '#d85e51'),
    'c2'  = c('#81adcf', 'white', '#ab90bd'),
    'c3'  = c('#84a7da', 'white', '#a97ca1'),
    'c4'  = c('#84a7da', 'white', '#efa29e'),
    'c5'  = c('#5dbed3', 'white', '#e54d36'),
    'c6'  = c('#663d74', 'white', '#fac03d'),
    'c7'  = c('#5a83bc', 'white', '#b65454'),
    'c8'  = c('#4c8364', 'white', '#aa5cb9'),
    'c9'  = c('#478497', 'white', '#c3593d'),
    'c10' = c("#4dbbd5", 'white', "#e64b35"),
    'c11'  = c('#57147d', '#fa815e', '#fce6a8'),
    'c12'  = c('#c0e4d6', '#6a90b1', '#4e4678')
  )
  
  return(colors[[cmap]])
}
  
#-------------------------------------------------------------------- END -------------------------------------------------------------------- 