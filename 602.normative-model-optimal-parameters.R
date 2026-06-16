# Clean environment and set working directory
rm(list = ls())
setwd("/dssg/home/acct-medlf/medlf17/users/dengchijun/topics/asd-mri-subtype/codes/asd-mri-subtype")

library(data.table)

# Define paths
PJ.DIR <- "/dssg/home/acct-medlf/medlf17/users/dengchijun/topics/asd-mri-subtype"
MODEL.PATH <- file.path(PJ.DIR, "results/lifespan/BIC/MODEL")
SAVE.PATH <- file.path(PJ.DIR, "results/lifespan/BIC/PARAMETER")

# Create SAVE.PATH directory if it doesn't exist
if (!dir.exists(SAVE.PATH)) dir.create(SAVE.PATH, recursive = TRUE)

#-----------------------------------------------------Fetch Model BIC-----------------------------------------------------
# List all .csv files
csv_files <- list.files(MODEL.PATH, pattern = "\\.csv$", full.names = TRUE)

# Read and combine all csvs into one data.table
bic_models <- rbindlist(lapply(csv_files, fread), use.names = TRUE, fill = TRUE)

# Reshape to wide format
bic_models_wide <- dcast(bic_models, phenotype ~ model, value.var = "BIC")

#-----------------------------------------------------END-----------------------------------------------------

#-----------------------------------------------------Select Best Model (lowest BIC)-----------------------------------------------------
# Exclude the phenotype column to find min BIC across models
bic_values <- bic_models_wide[, -1, with = FALSE]

# For each row, find the column (model) with the lowest BIC
best_models <- apply(bic_values, 1, function(row) {
  colnames(bic_values)[which.min(row)]
})

# Compute min and max BIC for each phenotype
min_BICs <- apply(bic_values, 1, min, na.rm = TRUE)
max_BICs <- apply(bic_values, 1, max, na.rm = TRUE)

# Compute log(max - min)
log_lift <- log(max_BICs - min_BICs)

# Combine results
best_model <- data.table(
  phenotype = bic_models_wide$phenotype,
  model_id = best_models,
  min_BIC = min_BICs,
  max_BIC = max_BICs,
  log_lift = log_lift
)

# Split phenotype into measure and region
best_model[, c("measure", "region") := tstrsplit(phenotype, "-", fixed = TRUE)]
setcolorder(best_model, c("measure", "region", setdiff(names(best_model), c("measure", "region"))))

# Save results
fwrite(best_model, file.path(SAVE.PATH, "best_model.csv"))
fwrite(bic_models_wide, file.path(SAVE.PATH, "model_bic.csv"))

#-----------------------------------------------------END-----------------------------------------------------


