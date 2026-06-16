rm(list=ls())
source("100.common-variables.r")
source("101.common-functions.r")

source("300.variables.r")
source("301.functions.r")

library("doSNOW")
library("foreach")


## Fitting model list
TO.FIT <- list()
COUNTER <- 1

for (measure in c('CT', 'SA', 'GMV')) {
  DATA.TAG <- measure
  DATA.PATH <- file.path(RDS.DIR, DATA.TAG)
  DATA.TAG = measure
  DATA.PATH <- file.path( RDS.DIR, DATA.TAG )
  DATA = readRDS(file=file.path( DATA.PATH, "DATA.rds"))

  # Get attributes
  COLUMNS = attr(DATA,"columns")
  for (OUTCOME in COLUMNS$Outcomes) {
    lset = sprintf("%s/%s", DATA.TAG, OUTCOME )
    
      PATHS.LIST <- Create.Folders( lset )
      MODEL.SET <- Find.Models.To.Fit( PATHS.LIST )
      for( lmod in MODEL.SET ) {
        TO.FIT[[COUNTER]] <- list(subset=lset,model=lmod)
        STR <- sprintf("[%3i] %s %s",COUNTER,lset,lmod)
        cat( STR, "\n" )
        COUNTER <- COUNTER + 1
      }
    }
}

# Fitting models for each brain region (even on HPC platforms, the fitting time is so long it's a nightmare)
# 64 * 40 CPU cores used in the trainning process...
# The gamlss model convergence is so slow, I will rewrite the gamlss wrapper with gamlss2 if I have extra time...

CLUSTER <- makeCluster(BOOT.OPT$Number.Cluster)
registerDoSNOW(CLUSTER)

PROGRESS <- txtProgressBar(max = BOOT.OPT$Number.Replicates, style = 3)
OPTS <- list(progress=function(n) setTxtProgressBar(PROGRESS, n))

FOREACH <- foreach(n=1:length(TO.FIT), .options.snow=OPTS, .inorder=FALSE)

RETURN <- FOREACH %dopar% Fit.Function(idx=n, List=TO.FIT)

close(PROGRESS)
stopCluster(CLUSTER)
  
print( warnings() ) 


