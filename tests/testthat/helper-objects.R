# this files contains the objects used in the tests:

travis <- T
saveLoc <- 'T:/Temp'
saveLoc <- getwd()
if(!dir.exists(file.path(saveLoc,"fftemp"))){
  dir.create(file.path(saveLoc,"fftemp"), recursive = T)
}
options(fftempdir = file.path(saveLoc,"fftemp"))


#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# simulated data Tests
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

data(plpDataSimulationProfile, envir = environment())

# PLPDATA
sampleSize <- 2000+sample(1000,1)
plpData <- simulatePlpData(plpDataSimulationProfile, n = sampleSize)
plpData$metaData$cohortId <- plpData$metaData$cohortIds

sampleSize2 <- 1000+sample(1000,1)
plpData2 <- simulatePlpData(plpDataSimulationProfile, n = sampleSize2)
plpData2$metaData$cohortId <- plpData2$metaData$cohortIds

# temporal - make less covs?
plpData3 <- simulatePlpData(plpDataSimulationProfile, n = sampleSize2)
plpData3$metaData$cohortId <- plpData3$metaData$cohortIds

# filter out to 10 covariates
#covIds <- unique(ff::as.ram(plpData3$covariates$covariateId))[1:10]
#ind <- ff::as.ram(plpData3$covariates$covariateId)%in%covIds
#plpData3$covariates <- plpData3$covariates[ind,]

plpData3$timeRef <- ff::as.ffdf(data.frame(timeId = 1:10))
plpData3$covariates$timeId <- ff::as.ff(sample(10, nrow(plpData3$covariates), replace = T))


# POPULATION
population <- createStudyPopulation(plpData,
                                    outcomeId = 2,
                                    firstExposureOnly = FALSE,
                                    washoutPeriod = 0,
                                    removeSubjectsWithPriorOutcome = FALSE,
                                    priorOutcomeLookback = 99999,
                                    requireTimeAtRisk = T,
                                    minTimeAtRisk=10,
                                    riskWindowStart = 0,
                                    startAnchor = 'cohort start',
                                    riskWindowEnd = 365,
                                    endAnchor = 'cohort start')

population2 <- createStudyPopulation(plpData2,
                                    outcomeId = 2,
                                    firstExposureOnly = FALSE,
                                    washoutPeriod = 0,
                                    removeSubjectsWithPriorOutcome = FALSE,
                                    priorOutcomeLookback = 99999,
                                    requireTimeAtRisk = T,
                                    minTimeAtRisk=10,
                                    riskWindowStart = 0,
                                    startAnchor = 'cohort start',
                                    riskWindowEnd = 365,
                                    endAnchor = 'cohort start')


# MODEL SETTINGS
lrSet <- setLassoLogisticRegression()
gbmSet <- setGradientBoostingMachine(ntrees = 50, maxDepth = 3, learnRate = 0.01, seed = 1)
knnSet <- setKNN(k=100, indexFolder = file.path(saveLoc,"knn"))
rfSet2 <- setRandomForest(mtries = -1,ntrees = 10, maxDepth = 2, varImp = F, seed=1)


# RUNPLP - LASSO LR
plpResult <- runPlp(population = population,
                                            plpData = plpData, 
                                            modelSettings = lrSet, 
                                            savePlpData = F, 
                                            savePlpResult = F, 
                                            saveEvaluation = F, 
                                            savePlpPlots = F, 
                                            analysisId = 'lrTest',
                                            saveDirectory =  saveLoc)


# learningCurve 
learningCurve <- createLearningCurve(population = population, 
                                     plpData = plpData, 
                                     modelSettings = lrSet, 
                                     testSplit = 'time', 
                                     testFraction = 0.25, 
                                     trainFractions = c(0.5,0.6), 
                                     nfold = 3, 
                                     clearffTemp = T, 
                                     analysisId = 'learningCurve',
                                     saveDirectory =  saveLoc
                                     )


#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@
# read data Tests
#@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@

#======== TEST-APPLY =============
cdmDatabaseSchema <- Sys.getenv("CDM5_POSTGRESQL_CDM_SCHEMA")
ohdsiDatabaseSchema <- Sys.getenv("CDM5_POSTGRESQL_OHDSI_SCHEMA")
connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = "postgresql",
                                                                user = Sys.getenv("CDM5_POSTGRESQL_USER"),
                                                                password = URLdecode(Sys.getenv("CDM5_POSTGRESQL_PASSWORD")),
                                                                server = Sys.getenv("CDM5_POSTGRESQL_SERVER"))

# create the cohorts
createCohort <- F
if(createCohort){
  conn <- DatabaseConnector::connect(connectionDetails)
  sql <- SqlRender::render(sql = 'select * into  @ohdsiDatabaseSchema.cohorts from (SELECT 1 as COHORT_DEFINITION_ID, PERSON_ID as SUBJECT_ID, min(CONDITION_START_DATE) as COHORT_START_DATE, min(CONDITION_START_DATE) as COHORT_END_DATE from @cdmDatabaseSchema.condition_occurrence where CONDITION_CONCEPT_ID=320128
 group by PERSON_ID) temp limit 1000;',
                           cdmDatabaseSchema = cdmDatabaseSchema ,
                           ohdsiDatabaseSchema = ohdsiDatabaseSchema)
  DatabaseConnector::executeSql(conn, sql)
  
  sql <- SqlRender::render(sql = 'select * into  @ohdsiDatabaseSchema.outs_test from (select 2 as COHORT_DEFINITION_ID, SUBJECT_ID, COHORT_START_DATE, COHORT_END_DATE from cohort) temp  limit 100;',
                           ohdsiDatabaseSchema = ohdsiDatabaseSchema)
  DatabaseConnector::executeSql(conn, sql)
}

covSet <- FeatureExtraction::createCovariateSettings(useDemographicsGender = T, useDemographicsAgeGroup = T)#  useConditionOccurrenceShortTerm = T)
plpDataReal <- getPlpData(connectionDetails = connectionDetails, 
                          cdmDatabaseSchema = cdmDatabaseSchema, 
                          cohortId = 1, outcomeIds = 2, 
                          cohortDatabaseSchema = ohdsiDatabaseSchema, 
                          cohortTable = 'cohorts', 
                          outcomeDatabaseSchema = ohdsiDatabaseSchema, 
                          outcomeTable = 'outs_test', 
                          sampleSize = 1000, 
                          covariateSettings = covSet)
plpDataReal$metaData$call$cdmDatabaseSchema <- Sys.getenv("CDM5_POSTGRESQL_CDM_SCHEMA")

populationReal <- createStudyPopulation(plpDataReal,
                                        outcomeId = 2,
                                        firstExposureOnly = FALSE,
                                        washoutPeriod = 0,
                                        removeSubjectsWithPriorOutcome = FALSE,
                                        priorOutcomeLookback = 99999,
                                        requireTimeAtRisk = F,
                                        minTimeAtRisk=1,
                                        riskWindowStart = 0, 
                                        startAnchor = 'cohort start',
                                        riskWindowEnd = 1000,
                                        endAnchor = 'cohort end')

plpResultReal <- runPlp(population = populationReal,
                        plpData = plpDataReal, 
                        modelSettings = rfSet2, 
                        splitSeed = 1,
                        savePlpData = F, 
                        savePlpResult = F, 
                        saveEvaluation = F, 
                        savePlpPlots = F, 
                        analysisId = 'gbmReal',
                        saveDirectory =  saveLoc)


