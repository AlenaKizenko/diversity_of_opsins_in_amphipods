## Sometimes makes life easier, and it's default in the new R anyway, 
## so for the sake of version independency:
options(stringsAsFactors = F)

## Load the necessary packages
library(ggtree)
library(ggplot2)
## if ggtree isn't installed AND if installing ggtree doesn't work
#install.packages("tidytree") #it is on CRAN!
## install the main package
library(magrittr)
library(tidyr)
library(RColorBrewer)
library(gridSVG)


## We need to tweak the gheatmap function to get borders around the boxes
gheatmap <- function (p, data, offset = 0, width = 1, low = "green", high = "red", 
                      color = "white", colnames = TRUE, colnames_position = "bottom", 
                      colnames_angle = 0, colnames_level = NULL, colnames_offset_x = 0, 
                      colnames_offset_y = 0, font.size = 4, hjust = 0.5) 
{
  colnames_position %<>% match.arg(c("bottom", "top"))
  variable <- value <- lab <- y <- NULL
  width <- width * (p$data$x %>% range(na.rm = TRUE) %>% diff)/ncol(data)
  isTip <- x <- y <- variable <- value <- from <- to <- NULL
  df <- p$data
  df <- df[df$isTip, ]
  start <- max(df$x, na.rm = TRUE) + offset
  dd <- as.data.frame(data)
  i <- order(df$y)
  i <- i[!is.na(df$y[i])]
  lab <- df$label[i]
  dd <- dd[match(lab, rownames(dd)), , drop = FALSE]
  dd$y <- sort(df$y)
  dd$lab <- lab
  dd <- gather(dd, variable, value, -c(lab, y))
  i <- which(dd$value == "")
  if (length(i) > 0) {
    dd$value[i] <- NA
  }
  if (is.null(colnames_level)) {
    dd$variable <- factor(dd$variable, levels = colnames(data))
  }
  else {
    dd$variable <- factor(dd$variable, levels = colnames_level)
  }
  V2 <- start + as.numeric(dd$variable) * width
  mapping <- data.frame(from = dd$variable, to = V2)
  mapping <- unique(mapping)
  dd$x <- V2
  dd$width <- width
  dd[[".panel"]] <- factor("Tree")
  if (is.null(color)) {
    p2 <- p + geom_tile(data = dd, aes(x, y, fill = value), 
                        width = width, inherit.aes = FALSE)
  }
  else {
    p2 <- p + geom_tile(data = dd, aes(x, y, fill = value), 
                        width = width, color = color, height = 0.7, inherit.aes = FALSE)
  }
  if (is(dd$value, "numeric")) {
    p2 <- p2 + scale_fill_gradient(low = low, high = high, 
                                   na.value = NA)
  }
  else {
    p2 <- p2 + scale_fill_discrete(na.value = NA)
  }
  if (colnames) {
    if (colnames_position == "bottom") {
      y <- 0
    }
    else {
      y <- max(p$data$y) + 1
    }
    mapping$y <- y
    mapping[[".panel"]] <- factor("Tree")
    p2 <- p2 + geom_text(data = mapping, aes(x = to, y = y, 
                                             label = from), size = font.size, inherit.aes = FALSE, 
                         angle = colnames_angle, nudge_x = colnames_offset_x, 
                         nudge_y = colnames_offset_y, hjust = hjust)
  }
  p2 <- p2 + theme(legend.position = "right", legend.title = element_blank())
  if (!colnames) {
    p2 <- p2 + scale_y_continuous(expand = c(0, 0))
  }
  attr(p2, "mapping") <- mapping
  return(p2)
}


## Switch to build either the nucleotide or amino acid tree
tr <- read.iqtree("data/2.4_Fig2_tree_rnaspades_nt.nwk")
#tr <- read.iqtree("data/2.4_FigS2_tree_rnaspades_aa.nwk")

## aLRT > 70% or aBayes >0.7 => a red dot
label <- tr@phylo$node.label
## Get aLRT from newick and identify large values
alrt <- as.numeric(sub("/.*", "", label))
bigalrt <- alrt > 70 & !is.na(alrt)
## Get aBayes from newick and identify large values
bayes <- as.numeric(sub(".*/", "", label))
bigbayes <- bayes > 0.7 & !is.na(bayes)
## add red dots where appropriate
newlabel <- ifelse(bigalrt & bigbayes, "red3", "#00000000")
tr@phylo$node.label <- newlabel

## Add metadata (the number of opsins) to the tree
meta.df <- read.csv("data/2.4_metadata.csv", row.names = 2)[, 2:4]
## make it a factor with the right order of levels
meta.df[,1] <- as.factor(meta.df[,1])
meta.df[,2] <- as.factor(meta.df[,2])
meta.df[,3] <- as.factor(meta.df[,3])
levels(meta.df[,1]) <- c(levels(meta.df[,1]), 2, 3)
meta.df[,1] <- relevel(meta.df[,1], ref = "0")
levels(meta.df[,2]) <- c(levels(meta.df[,2]), 0)
meta.df[,2] <- relevel(meta.df[,2], ref = "0")
levels(meta.df[,3]) <- c(levels(meta.df[,3]), 0)
meta.df[,3] <- relevel(meta.df[,3], ref = "0")

## Get rid of underscores in the species names
tr@phylo$tip.label <- gsub("_", " ", tr@phylo$tip.label)
row.names(meta.df) <- gsub("_", " ", row.names(meta.df))

## Build the initial tree
ptr <- ggtree(tr) + geom_tiplab(align = T, fontface = "italic", offset = .15, linetype = "dotted", linesize = .2) + 
  geom_nodepoint(size = 1, color = newlabel) 
## Take a look (totally optional)
ptr
## Flip two branches for easier comprehension
ptr3 <- flip(ptr, 67, 64)


## Color scheme (violets)
colors <- c("#FFFFFF", "#d2beed", "#a57edb", "#6929c4", "#491c89", "#000000")
names(colors) <- c("0", "1", "2", "3", "4", "5")
## Add the heatmap (or rather the table) to the tree
ptr2 <- gheatmap(p = ptr3, meta.df, color = "black",
                 width=.18, offset=-0.01, colnames=T, colnames_position = "top", 
                 colnames_offset_y = .25, colnames_offset_x = c(-1/60, 0, 1/60), 
                 colnames_angle = 0, font.size = 3.5) +
  scale_fill_manual(values=colors, name = "Found opsins") +  ##name doesn't work , labels = names(colors) just not necessary
  theme(legend.position = c(0.1, 0.78), legend.margin = margin(t = 0, unit='cm')) + 
  xlim(0, 1.4) + 
  annotate("text", x=0.06, y=36, label = "Found opsins") + 
  annotate("text", x=0.01, y=20.8, label = intToUtf8(9679), col = "red3") +
  annotate("text", x=0.12, y=20, label = "aBayes > 0.7 & \n aLRT > 70%") 
## Again, take a look
ptr2 

## Add clade labels, and this is the final tree!
ptr2 + geom_cladelabel(44, 'Baikal group 2', offset=.9, offset.text=.02, extend = .5,
                       barsiz=1, color='#0072B2', angle=90, hjust='center', alpha = 1) +
  geom_hilight(44, fill = '#0072B2', alpha = .2) +
  geom_cladelabel(67, 'Europe', offset=.75, offset.text=.02, extend = .5,
                  barsiz=1, color='#E69F00', angle=90, hjust='center') +
  geom_hilight(67, fill = '#E69F00', alpha = .2) +
  geom_cladelabel(64, 'Baikal group 1', offset=.9, offset.text=.02, extend = .5,
                  barsiz=1, color='#0072B2', angle=90, hjust='center') +
  geom_hilight(64, fill = '#0072B2', alpha = .2) +
  geom_cladelabel(70, 'Talitridae', offset=.945, offset.text=.02, extend = .5,
                  barsiz=1, color='#CC79A7', angle=90, hjust='center') + 
  geom_hilight(70, fill = '#CC79A7', alpha = .2) +
  geom_cladelabel(39, 'Gammaridae', offset=1, offset.text=.02, extend = .5,
                  barsiz=1, color='darkgreen', angle=90, hjust='center')

## Save the image (again, a switch between nucleotide / aa tree)
ggsave("nt_tree.svg", width=24, height=18, units="cm")
ggsave("nt_tree.png", width=24, height=18, units="cm")
#ggsave("aa_tree.svg", width=24, height=18, units="cm")
#ggsave("aa_tree.png", width=24, height=18, units="cm")
