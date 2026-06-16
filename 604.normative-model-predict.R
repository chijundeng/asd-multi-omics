rm(list = ls())
setwd("/dssg/home/acct-medlf/medlf17/users/dengchijun/topics/asd-mri-subtype/codes/asd-mri-subtype")
library(parallel)
library(data.table)  # for fread()

# Load resources
source("100.common-variables.r")
source("101.common-functions.r")
source("300.variables.r")
source("301.functions.r")

# Set directories
PJ.DIR <- "/dssg/home/acct-medlf/medlf17/users/dengchijun/topics/asd-mri-subtype"
BIC.PATH <- file.path(PJ.DIR, "results/lifespan/BIC/PARAMETER")
SAVE.CENTILE <- file.path(PJ.DIR, "results/lifespan/CENTILES")

# Create output folder if it doesn't exist
if (!dir.exists(SAVE.CENTILE)) {
  dir.create(SAVE.CENTILE, recursive = TRUE)
}

# Load best model table
best_model <- fread(file.path(BIC.PATH, "best_model.csv"))

# Loop over measures
for (measure in c("CT", "SA", "GMV")) {
  
  DATA.TAG <- measure
  DATA.PATH <- file.path(RDS.DIR, DATA.TAG)
  
  DATA <- readRDS(file = file.path(DATA.PATH, "DATA.rds"))
  ASD <- readRDS(file = file.path(DATA.PATH, "ASD.rds"))
  
  # Get outcome columns
  COLUMNS <- attr(DATA, "columns")
  
  # Initialize centile storage
  ASD.CENTILES <- matrix(NA, nrow = length(ASD$SubID), ncol = length(COLUMNS$Outcomes),
                         dimnames = list(ASD$SubID, COLUMNS$Outcomes))
  ASD.CENTILES <- as.data.frame(ASD.CENTILES)
  
  for (OUTCOME in COLUMNS$Outcomes) {
    
    MODEL_TAG <- sprintf("%s/%s", DATA.TAG, OUTCOME)
    PATHS <- Create.Folders(MODEL_TAG)
    
    # Fetch best model file
    phenotype_key <- gsub("/", "-", MODEL_TAG)
    opt_model <- best_model[phenotype == phenotype_key, model_id]
    model_bfp <- paste0("base", opt_model, ".GGalt.bfpNA.rds")
    
    # Create symlinks if not exist
    model_link <- file.path(PATHS$PATH, "MODEL.rds")
    extract_link <- file.path(PATHS$PATH, "FIT.EXTRACT.rds")
    
    # Remove existing symlinks if they exist, then create new ones
    if (file.exists(model_link)) file.remove(model_link)
    if (file.exists(extract_link)) file.remove(extract_link)
    
    file.symlink(from = file.path(PATHS$MODEL, model_bfp), to = model_link)
    file.symlink(from = file.path(PATHS$FIT.EXTRACT, model_bfp), to = extract_link)
    
    # Load primary components
    PRIMARY <- Load.Subset.Wrapper(
      Tag = MODEL_TAG,
      LSubset = TRUE,
      LModel = TRUE,
      LFit = TRUE,
      LBoot = FALSE
    )
    
    # Compute centile predictions
    PRIMARY$SUBSET.PRED <- Apply.Param(
      NEWData = PRIMARY$SUBSET,
      Reference.Holder = PRIMARY,
      FITParam = PRIMARY$FIT.EXTRACT$param,
      Pred.Set = c("l025" = 0.025, "l250" = 0.250, "m500" = 0.5, "u750" = 0.750, "u975" = 0.975),
      Add.Moments = FALSE,
      Add.Normalise = TRUE,
      Add.Derivative = FALSE,
      MissingToZero = TRUE,
      NAToZero = TRUE
    )
    
    # Generate curve
    age_range <- range(PRIMARY$SUBSET[,"AgeTransformed"])
    PRIMARY$CURVE <- Apply.Param(
      NEWData = expand.grid(list(
        AgeTransformed = seq(age_range[1], age_range[2], length.out = 2^10),
        Sex = c("Male", "Female")
      )),
      FITParam = PRIMARY$FIT.EXTRACT$param
    )
    
    # Predict ASD subset
    ASD.SUBSET <- readRDS(file.path(PATHS$PATH, "ASD/ASD.SUBSET.rds"))
    PRIMARY$ASD.PRED <- Apply.Param(
      NEWData = ASD.SUBSET,
      FITParam = PRIMARY$FIT.EXTRACT$param,
      Reference.Holder = PRIMARY,
      Pred.Set = NULL,
      Prefix = "",
      Add.Moments = FALSE,
      Add.Normalise = FALSE,
      Add.Derivative = FALSE,
      MissingToZero = TRUE,
      verbose = FALSE
    )
    
    # Store predicted quantile for outcome
    matched_idx <- match(ASD.SUBSET$SubID, PRIMARY$ASD.PRED[["SubID"]])
    pred_col <- paste0(OUTCOME, ".q.wre")
    ASD.CENTILES[ASD.SUBSET$SubID, OUTCOME] <- PRIMARY$ASD.PRED[[pred_col]][matched_idx]
    
    # Save full PRIMARY object
    saveRDS(object = PRIMARY, file = file.path(PATHS$PATH, "PRIMARY.rds"))
    
    # Check NA values
    hasNA <- anyNA(PRIMARY$ASD.PRED[[pred_col]])
    print(paste0("NA values of ASD for ", OUTCOME, ": ", hasNA))
  }
  
  # Save centiles for current measure
  write.csv(ASD.CENTILES, file = file.path(SAVE.CENTILE, paste0(measure, ".ASD.CENTILES.csv")), row.names = TRUE)
}

