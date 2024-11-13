library(betAS)
dataset_raw <- getDataset(pathTables=file.choose(), tool="vast-tools")
dataset <- getEvents(dataset_raw, tool = "vast-tools")

# Remove the first "X" in the list dataset$Samples in each name

gene <- "Myo5b"
head(dataset$PSI[dataset$PSI$GENE==gene,])
event_of_interest <- "MmuEX1017999"
dataset$PSI[dataset$PSI$EVENT==event_of_interest,]
dataset$EventsPerType

dataset_filtered <- filterEvents(dataset, types=c("C1", "C2", "C3", "S", "MIC"), N=10)
cat(paste0("Alternative events: ", nrow(dataset_filtered$PSI)))

dataset_filtered <- alternativeEvents(dataset_filtered, minPsi=1, maxPsi=99)

cat(paste0("Alternative events: ", nrow(dataset_filtered$PSI)))

bigPicturePlot <- bigPicturePlot(table = dataset_filtered$PSI)
bigPicturePlot + theme_minimal()

dataset_filtered$Samples

metadata <- read.csv(file.choose(), sep = "\t")
# Extract only the odd rows
metadata <- metadata[seq(1, nrow(metadata), by = 2),]

# Define the grouping variable and get the unique groups
groupingVariable <- "Description"
groups <- unique(metadata[, groupingVariable])

# Define vector of sample names based on the example metadata 
samples <- metadata$fastq_files

# Define colors for the groups, assuming there are at least as many colors as groups
random_colors <- c("#FF9AA2", "#FFB7B2", "#FFDAC1")

# Initialize groupList as an empty list
groupList <- list()

for (i in 1:length(groups)) {
  # Get sample names for the current group
  groupNames <- samples[which(metadata[, groupingVariable] == groups[i])]
  
  # Add the group to groupList
  groupList[[groups[i]]] <- list(
    name = groups[i],
    samples = groupNames,
    color = random_colors[i]
  )
}

# Print the groupList to check if the output is as expected
print(groupList)

# Visualize colors being used
slices <- rep(1, length(groupList))  # Equal-sized slices for each color
# Display the pie chart with colors
pie(slices, col = random_colors[1:length(groupList)], border = "black", labels=names(groupList), main = "Color palette for group definition")


# Define groups
groupA    <- "ControlFmn2+-"
groupB    <- "Fmn2+-_+10mMPlatB"
# Define samples inside each group
samplesA    <- groupList[[groupA]]$samples
samplesB    <- groupList[[groupB]]$samples
dataset_filtered$Samples <- gsub("X", "", dataset_filtered$Samples)
# Convert samples into indexes
colsGroupA    <- convertCols(dataset_filtered$PSI, samplesA)
colsGroupB    <- convertCols(dataset_filtered$PSI, samplesB)
# remove NA from this lists


set.seed(66)


options(error=recover)
volcanoTable_Pdiff <- prepareTableVolcano(psitable = dataset_filtered$PSI,
                                          qualtable = dataset_filtered$Qual,
                                          npoints = 500,
                                          colsA = colsGroupA,
                                          colsB = colsGroupB,
                                          labA = groupA,
                                          labB = groupB,
                                          basalColor = "#89C0AE",
                                          interestColor = "#E69A9C",
                                          maxDevTable = maxDevSimulationN100, 
                                          seed=TRUE, 
                                          CoverageWeight = FALSE)

volcano_Pdiff <- plotVolcano(betasTable = volcanoTable_Pdiff,
                             labA = groupA,
                             labB = groupB,
                             basalColor = "#89C0AE",
                             interestColor = "#E69A9C") 

volcano_Pdiff