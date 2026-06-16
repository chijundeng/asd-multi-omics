rm(list=ls())

source("100.common-variables.r")
source("101.common-functions.r")

source("300.variables.r")
source("301.functions.r")

library("doSNOW")
library("foreach") 


Print.Disclaimer( )

# Number of HPC clusters
CLUSTERS = 50

# Cortical feature
BOOT.SET = c("CT/cortex", "SA/cortex", "GMV/cortex")
  
for( lset in BOOT.SET ) {
  cat( "=====", lset, "=====\n" )
  
  PATHS.LIST <- Create.Folders( Tag=lset )
  
  HOLDER <- Load.Subset.Wrapper( Tag=lset, LSubset=TRUE, LModel=TRUE, LFit=TRUE )
  
  CLUSTER <- makeCluster(CLUSTERS)
  registerDoSNOW(CLUSTER)
  
  PROGRESS <- txtProgressBar(max = BOOT.OPT$Number.Replicates, style = 3)
  OPTS <- list(progress=function(n) setTxtProgressBar(PROGRESS, n))
  
  FOREACH.OBJ <- foreach(n=1:BOOT.OPT$Number.Replicates, .options.snow=OPTS, .packages=c("gamlss")) 
  
  BOOT.EXTRACT <- FOREACH.OBJ %dopar% Boot.Function(n=n,Base.Seed=BOOT.OPT$Seed,Holder=HOLDER)
  
  saveRDS(object=BOOT.EXTRACT,file=file.path(PATHS.LIST$BOOT.EXTRACT,sprintf("s%05i+n%05i.rds",BOOT.OPT$Seed,BOOT.OPT$Number.Replicates)))
  
  close(PROGRESS)
  stopCluster(CLUSTER)
  
}

print( warnings() ) 

