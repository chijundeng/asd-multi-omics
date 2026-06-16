# You can skip the step if you have already fitted all models in the model-fitting step
# Clean environment and set working directory
rm(list = ls())
setwd("/dssg/home/acct-medlf/medlf17/users/dengchijun/topics/asd-mri-subtype/codes/asd-mri-subtype")

# Load source files
source("100.common-variables.r")
source("101.common-functions.r")
source("300.variables.r")
source("301.functions.r")

# Load required packages
library("doSNOW")
library("foreach")
library("data.table") 

# Load optimal model info
PJ.DIR <- "/dssg/home/acct-medlf/medlf17/users/dengchijun/topics/asd-mri-subtype"
BIC.PATH <- file.path(PJ.DIR, "results/lifespan/BIC/PARAMETER")
best_model <- fread(file.path(BIC.PATH, "best_model.csv"))

# Initialize task list
TO.FIT <- list()
COUNTER <- 1

# Loop through CT, SA, GMV
for (measure in c("CT", "SA", "GMV")) {
  DATA.TAG <- measure
  DATA.PATH <- file.path(RDS.DIR, DATA.TAG)
  DATA <- readRDS(file = file.path(DATA.PATH, "DATA.rds"))
  
  # Get outcome columns
  COLUMNS <- attr(DATA, "columns")
  
  for (OUTCOME in COLUMNS$Outcomes) {
    lset <- sprintf("%s/%s", DATA.TAG, OUTCOME)
    PATHS.LIST <- Create.Folders(lset)
    MODEL.SET <- Find.Models.To.Fit(PATHS.LIST)
    
    for (lmod in MODEL.SET) {
      # Extract model id from filename
      model_id <- sub(".*(FO\\d+R\\d+).*", "\\1", lmod)
      
      # Create phenotype string for matching
      phenotype_key <- gsub("/", "-", lset)
      
      # Fetch corresponding best model id
      selected_model_id <- best_model[phenotype == phenotype_key, model_id]
      
      # Check if this is the best model
      if (length(selected_model_id) == 0 || model_id != selected_model_id) next
      
      # Append to fitting list
      TO.FIT[[COUNTER]] <- list(subset = lset, model = lmod)
      cat(sprintf("[%3i] %s %s", COUNTER, lset, lmod), "\n")
      COUNTER <- COUNTER + 1
    }
  }
}

# Run models in parallel
CLUSTER <- makeCluster(BOOT.OPT$Number.Cluster)
registerDoSNOW(CLUSTER)

PROGRESS <- txtProgressBar(max = length(TO.FIT), style = 3)
OPTS <- list(progress = function(n) setTxtProgressBar(PROGRESS, n))

RETURN <- foreach(n = seq_along(TO.FIT), .options.snow = OPTS, .inorder = FALSE) %dopar% {
  Fit.Function(idx = n, List = TO.FIT)
}

close(PROGRESS)
stopCluster(CLUSTER)

# Show any warnings
print(warnings())

