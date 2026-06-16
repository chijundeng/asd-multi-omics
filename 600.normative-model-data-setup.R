rm(list=ls())
setwd("/dssg/home/acct-medlf/medlf17/users/dengchijun/topics/asd-mri-subtype/codes/asd-mri-subtype")

list.of.packages <- c("dplyr", "readxl")
new.packages <- list.of.packages[!(list.of.packages %in% installed.packages()[,"Package"])]
if(length(new.packages)) install.packages(new.packages)
lapply(list.of.packages, require, character.only = TRUE)

source("100.common-variables.r")
source("101.common-functions.r")
source("200.variables.r")
source("201.functions.r")


for (measure in c('CT', 'SA', 'GMV') ){
 
  # Data path
  data_dir = paste0('/dssg/home/acct-medlf/medlf17/users/dengchijun/topics/asd-mri-subtype/data/stats_agg/', measure, '/', measure, '.csv')
  
  # Load data
  RAW.DATA <- read.csv(file.path( data_dir))
  
  # Run
  RAW.DATA$run = 1
  
  # Calculate the brain-wide mean measures
  rois <- grep("^lh_|^rh_", names(RAW.DATA), value = TRUE)
  if (measure %in% c('GMV', 'SA')) {
    RAW.DATA[, rois] = RAW.DATA[, rois] / 100
    RAW.DATA$cortex <- rowSums(RAW.DATA[, rois], na.rm = TRUE)
    RAW.DATA$cortex = RAW.DATA$cortex / 100
  } else if (measure %in% c('CT')) {
    RAW.DATA$cortex <- rowMeans(RAW.DATA[, rois], na.rm = TRUE)
  }
  
  # Select columns
  RAW.DATA$Sex = factor(RAW.DATA$Sex)
  RAW.DATA$Batch = factor(RAW.DATA$Batch)
  RAW.DATA$Diagnosis = factor(RAW.DATA$Diagnosis)
  
  # Transform
  TRANSFORMATIONS <- list()
  TRANSFORMATIONS[[ "X" ]] <- list("OriginalName"="Age",
                                   "TransformedName"="AgeTransformed",
                                   "toTransformed"=function(Z) { log(Z) }, ## must manually scale X-variable for numerical stability within bfpNA()
                                   "toOriginal"=function(Z) { exp(Z) }
  )
  RAW.DATA[,TRANSFORMATIONS[["X"]][["TransformedName"]]] <- TRANSFORMATIONS[["X"]][["toTransformed"]]( RAW.DATA[, TRANSFORMATIONS[["X"]][["OriginalName"]] ] )
  
  # Select columns
  COLUMNS <- list(Outcomes=union("cortex", rois),
                  Covariates=c("AgeTransformed","Batch","Sex"),
                  Additional=c("SubID","Diagnosis","Age", "AgeYear", "run")
  )
  
  DATA <- RAW.DATA[,unlist(COLUMNS)] ## only keep selected columns
  rm(RAW.DATA)
  
  # Set variables
  DATA$Sex.Raw <- DATA$Sex
  DATA$Sex <- factor(DATA$Sex==0,levels=c(TRUE,FALSE), labels=c("Male","Female"))
  warning("Assumptions regarding sex coding")
  
  ##
  ## Add INDEX.TYPE column, a script-defined column to separate individuals used to fit the model (ie healthy controls)
  ##
  DATA$INDEX.TYPE   <- factor(DATA$Diagnosis==0,levels=c(TRUE,FALSE),labels=c("TD","ASD"))
  DATA$Diagnosis <- relevel(DATA$INDEX.TYPE,"TD")
  
  ##
  ## Create unique identifier (INDEX.ID) for each person across all studies
  ## NOTE: This column will be used in later scripts, so it must exist!
  ##
  DATA$INDEX.ID <- factor( paste( DATA$Batch, DATA$SubID, DATA$Sex, sep="|" ) )
  warning("Created a bespoke INDEX.ID which \"should\" uniquely identify each individual")
  
  ##
  ## Reorder dataset
  ## NOTE: This assumes first scan (by age) corresponds to first scan of interest. This may not be true!
  ##
  DATA <- DATA[order(DATA$INDEX.ID,DATA$AgeTransformed),]
  
  DATA$INDICATOR.OB <- (DATA$run==1)
  COLUMNS$Additional <- append( COLUMNS$Additional, "INDICATOR.OB" )
  warning("Within real datasets using ( run==1 ) to select first run within each session")
  
  ##
  ## Create identifer for 'first' scan (INDEX.OB) within each person
  ## NOTE: This column will be used to subset to cross-sectional data, so it must exist!
  ##
  DATA$INDEX.OB <- NA
  DATA$INDEX.OB[ which(DATA$INDICATOR.OB) ] <- Reduce(c,lapply(rle(as.numeric(DATA$INDEX.ID[which(DATA$INDICATOR.OB)]))$lengths,function(k){1:k}))
  warning("Created a bespoke INDEX.OB which \"should\" identify repeat observations of individuals (akin to \"run\" variable)")
  
  ##
  ## Need to add these new columns to the 'to keep' list
  ##
  COLUMNS$Index <- c("INDEX.ID","INDEX.OB","INDEX.TYPE")
    
  ##
  ## Attaching some attributes
  ##
  DATA.TAG = measure
  
  attr(DATA,"columns") <- COLUMNS    
  
  attr(DATA,"tag") <- DATA.TAG
  
  attr(DATA,"Transformations") <- TRANSFORMATIONS
  
  ##
  ## Sanity checking dataset
  ##
  if( 1 ) {
    print( xtabs( ~ addNA(INDEX.OB), data=DATA ) )
    warning("Must ensure session+run Vs INDEX.OB mis-matches are valid (see commented out code to investigate mis-matches)")
    
    cat("\n\n")
  }
  
  ## Divide into TD/ASD
  # ASD
  ASD <- DATA[DATA$Diagnosis == "ASD", ]
  ASD <- droplevels(ASD)
  rownames(ASD) <- NULL

  # TD 
  DATA <- DATA[DATA$Diagnosis == "TD", ]
  DATA <- droplevels(DATA)
  rownames(DATA) <- NULL 
  
  ## Save data
  DATA.PATH <- file.path( RDS.DIR, DATA.TAG )
  
  # Create directory if it doesn't exist
  if (!dir.exists(DATA.PATH)) {
    dir.create(DATA.PATH, recursive = TRUE)
  }
  
  saveRDS(object=DATA, file=file.path( DATA.PATH, "DATA.rds"))
  saveRDS(object=ASD, file=file.path( DATA.PATH, "ASD.rds"))
  
  
  # Loop for each feature
  for( OUTCOME in COLUMNS$Outcomes ) {
    
    PATHS.LIST <- Create.Folders( Tag=sprintf("%s/%s", DATA.TAG, OUTCOME ) )
    
    ##
    ## Generate subsets (by outcome[=column] and included/excluded[=rows])
    ## NOTE: excluded implicitly means cross-sectional, ie. only 'first' observation
    ##
    
    WHICH <- list()
    
    WHICH$BASELINE.CONTROL <- with(DATA, (INDEX.TYPE==levels(INDEX.TYPE)[1]) & (INDEX.OB==1))
    warning("Current SUBSET is based on INDEX.ID and INDEX.OB assumptions, these might not be the correct way to subset the data")
    
    ## Following is outcome-specific code
    if(!is.null(COLUMNS$Drop)){
      MATCH <- match(x=sprintf("%s.DROP",OUTCOME), table=COLUMNS$Drop )
      if( !is.na(MATCH) ) {
        WHICH$KEEP <- !DATA[,COLUMNS$Drop] ## above we specify in terms of which rows to drop, so we must negate to keep those we want to KEEP
        cat("Outcome specific subsetting:",OUTCOME," (dropping ",sum(!WHICH$KEEP,na.rm=TRUE)," rows)\n")
      } else {
        WHICH$KEEP <- rep(TRUE,NROW(DATA))
      }
    } else {
      WHICH$KEEP <- rep(TRUE,NROW(DATA))
    }
    
    
    ##
    ## Check for NAs in Outcome, Covariates, Index and Drop columns (not Additional, since they do not impact fitting by definition)
    WHICH$VALID <- Reduce(`&`, lapply( DATA[c(OUTCOME,unlist( attr(DATA,"columns")[c("Covariates", "Index", "Drop")] ) )], function(X){!is.na(X)} ) )
    
    WHICH.COLUMNS <- c( OUTCOME, unlist( attr(DATA,"columns")[c("Covariates", "Additional", "Index", "Drop")] ) ) ## note explicitly including OUTCOME
    
    SUBSET <- droplevels( DATA[ Reduce( `&`, WHICH ), WHICH.COLUMNS ] )
    
    cat( "Subset", PATHS.LIST$PATH, "has", NROW(SUBSET), "rows.\n")
    
    attributes(SUBSET) <- c( attributes(SUBSET), attributes(DATA)[c("columns", "tag","Transformations")] )
    
    attr(SUBSET,"DATA.WHICH.LIST") <- WHICH
    
    ## Set the per-SUBSET trasnformation names for the Y-variable
    ## NOTE: we could imagine doing the outcome transformations within this for-loop
    ##       but since it is common to all outcomes, might as well do it above
    ##       (hence the need for thse lines below to 'fix' the Y-variable name)
    attr(SUBSET,"Transformations")[["Y"]]$OriginalName <- sub("Transformed","",OUTCOME)
    attr(SUBSET,"Transformations")[["Y"]]$TransformedName <- OUTCOME
    rownames(SUBSET) <- NULL
    saveRDS(object=SUBSET, file=file.path(PATHS.LIST$PATH,"SUBSET.rds"))
    
    ## ASD SUBSET
    ASD.SUBSET <- droplevels( ASD[ , WHICH.COLUMNS ] )
    rownames(ASD.SUBSET) <- NULL
    saveRDS(object=ASD.SUBSET, file=file.path(PATHS.LIST$ASD,"ASD.SUBSET.rds"))
    
    
    ##
    ## Generate model sets
    ##
    cat("Generating models...\n")
    
    
    ## NOTE: FAMILY.SET allows us to explore multiple gamlss outcome distributions, later scripts will select the 'best' (via AIC/BIC/etc)
    FAMILY.SET <- c("GGalt")
    FP.SET <- matrix(c(1,1,0,
                       2,1,0,
                       2,2,0,
                       3,1,0,
                       3,2,0,
                       3,3,0),
                     byrow=TRUE,ncol=3,dimnames=list(NULL,c("mu","sigma","nu")))
    
    RANDOM.SET <- matrix(c(1,0,0,
                           1,1,0
    ),
    byrow=TRUE,ncol=3,dimnames=list(NULL,c("mu","sigma","nu")))
    row.names(RANDOM.SET) <- LETTERS[1:NROW(RANDOM.SET)]
    RANDOM.STR <- c(""," + random(Batch)")
    
    for( lFAM in FAMILY.SET ) { ## loop to search multiple outcome distributions
      
      for( iFP in 1:NROW(FP.SET) ) {
        
        for( iRAND in 1:NROW(RANDOM.SET) ) {
          
          MODEL.NAME <- paste0("baseFO",paste0(FP.SET[iFP,],collapse=""),"R",paste0(RANDOM.SET[iRAND,],collapse=""))
          
          MODEL <- list(covariates=list("Y"=OUTCOME, ## The Outcome
                                        "X"="AgeTransformed", ## The main X-variable (continuous) for plotting against Y
                                        "ID"="SubID", ## Subject-level ID, will be superceded by INDEX.ID in later scripts
                                        "BY"="Sex", ## factor columns to stratify plots (and implicitly within the model)
                                        "OTHER"=NULL, ## other variables (note: in later scripts if missing these will be set to zero)
                                        "COND"="Diagnosis", ## should be all equal to base case in fitted SUBSET
                                        "RANEF"="Batch"),
                        family=lFAM,
                        contrasts=list("Sex"="contr.sum"), 
                        stratify=c("Batch","Sex"),
                        mu=if(FP.SET[iFP,"mu"]>0){
                          sprintf("%s ~ 1 + Sex + fp(AgeTransformed,npoly = %i)%s",
                                  OUTCOME,
                                  FP.SET[iFP,"mu"],
                                  RANDOM.STR[RANDOM.SET[iRAND,"mu"]+1])
                        } else {
                          sprintf("%s ~ 1 + Sex%s",
                                  OUTCOME,
                                  RANDOM.STR[RANDOM.SET[iRAND,"mu"]+1])
                        },
                        sigma=if(FP.SET[iFP,"sigma"]>0){
                          sprintf("%s ~ 1 + Sex + fp(AgeTransformed,npoly = %i)%s",
                                  OUTCOME,
                                  FP.SET[iFP,"sigma"],
                                  RANDOM.STR[RANDOM.SET[iRAND,"sigma"]+1])
                        } else {
                          sprintf("%s ~ 1 + Sex%s",
                                  OUTCOME,
                                  RANDOM.STR[RANDOM.SET[iRAND,"sigma"]+1])
                        },
                        nu=if(FP.SET[iFP,"nu"]>0){
                          sprintf("%s ~ 1 + fp(AgeTransformed,npoly = %i)%s",
                                  OUTCOME,
                                  FP.SET[iFP,"nu"],
                                  RANDOM.STR[RANDOM.SET[iRAND,"nu"]+1])
                        } else {
                          sprintf("%s ~ 1%s",
                                  OUTCOME,
                                  RANDOM.STR[RANDOM.SET[iRAND,"nu"]+1])
                        },
                        inc.fp=TRUE)
          
          saveRDS(object=MODEL,file=file.path(PATHS.LIST$MODEL,sprintf("%s.%s.fp.rds",MODEL.NAME,lFAM)))
        }
      }
    }
    
  }
}

print( warnings() ) 
