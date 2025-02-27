library(TMB)
library(r4ss)
library(PacifichakeMSE)

mod <- SS_output('inst/extdata/SS32018/', printstats=FALSE, verbose = FALSE) # Read the true selectivity
compile("src/runHakeassessment.cpp")
dyn.load(dynlib("src/runHakeassessment"))
# Set the seed
seedz <- 12345
set.seed(seedz)

# source('R/load_files.R')
# source('R/load_files_OM.R')
# source('R/run_multiple_OMs.R')
nruns <- 100
seeds <- floor(runif(n = nruns, min = 1, max = 1e6))

ls.save <- list()
ls.converge <- matrix(0, nruns)
df <- load_data_seasons(nseason = 4, nspace = 2) # Prepare data for operating model
df$bfuture <- 0


for (i in 1:nruns){
  tmp <- run_multiple_OMs(simyears = 50, seeds[i], df =df, Catchin =0)
  #tmp <- run_multiple_MSEs(simyears = 30, seeds[i])
  print(i)
  if(is.list(tmp)){
    ls.save[[i]] <-tmp
    ls.converge[i] <- 1
  }else{
    ls.save[[i]] <- NA
    ls.converge[i] <- 0
  }

}
# # # #
save(ls.save,file = 'results/bias adjustment/MSErun_move_nofishing_nobiasadj.Rdata')

ls.save <- list()
ls.converge <- matrix(0, nruns)
df <- load_data_seasons(nseason = 4, nspace = 2, bfuture = 0.87) # Prepare data for operating model
source('run_multiple_OMs.R')


for (i in 1:nruns){
  tmp <- run_multiple_OMs(simyears = 50, seeds[i], df =df, Catchin =0)
  #tmp <- run_multiple_MSEs(simyears = 30, seeds[i])
  print(i)
  if(is.list(tmp)){
    ls.save[[i]] <-tmp
    ls.converge[i] <- 1
  }else{
    ls.save[[i]] <- NA
    ls.converge[i] <- 0
  }

}
# # # #
save(ls.save,file = 'results/bias adjustment/MSErun_move_nofishing_biasadj.Rdata')

ls.save <- list()
ls.converge <- matrix(0, nruns)
df <- load_data_seasons(nseason = 4, nspace = 2, bfuture = 0.5) # Prepare data for operating model


for (i in 1:nruns){
  tmp <- run_multiple_OMs(simyears = 50, seeds[i], df =df, Catchin =0)
  #tmp <- run_multiple_MSEs(simyears = 30, seeds[i])
  print(i)
  if(is.list(tmp)){
    ls.save[[i]] <-tmp
    ls.converge[i] <- 1
  }else{
    ls.save[[i]] <- NA
    ls.converge[i] <- 0
  }

}
# # # #
save(ls.save,file = 'results/bias adjustment/MSErun_move_nofishing_biasadj_med.Rdata')



# Plot stuff

df.MSE <- purrr::flatten(ls.save) # Change the list a little bit

tmp <- lapply(purrr::map(df.MSE[names(df.MSE) == 'id'],
                           .f = fnsum, idx = idx), data.frame, stringsAsFactors = FALSE)
