library(GBoost)
library(parallel)
library(foreach)
library(doParallel)
library(glmnet)
library(caret)
Rsqr <- function(X, Y, Y_mean){
  return(1-sum((X-Y)**2)/sum((Y-Y_mean)**2))
}
MSE <- function(X, Y){
  return(sum((X-Y)**2)/(length(X)-1))
}
rootPath = dirname(getwd())
setwd(rootPath)
dfPath = file.path(rootPath, 'df_gca.csv')
df = read.csv(dfPath)

net_info.path = file.path(rootPath, 'net_info.csv')
net_info = read.csv(net_info.path)
net = net_info$net_idx
nodes = length(net)

# index of lower & upper triangle
ind.tril = lower.tri(matrix(data = TRUE, nrow = nodes, ncol = nodes))
ind.triu = upper.tri(matrix(data = TRUE, nrow = nodes, ncol = nodes))

gp.parc = c()
for(i in 1:(nodes-1)){
  for(j in (i+1):nodes){
    # group index of each node of Glasser's 180 parcellation
    gp.parc = append(gp.parc, paste(as.character(net[j]), as.character(net[i]), sep = ':'))
  }
}
group = factor(x = gp.parc, levels = unique(gp.parc))

fc = data.table::fread(file.path(rootPath, 'fc_z_sel.csv'))
fc = as.matrix(fc)

SNreg <- function (idx.test, X, Y, group) {
  
  idx.train = c(1:nrow(X))[!(c(1:nrow(X)) %in% idx.test)]
  # model fitting of Scalar-on-network regression
  start = proc.time()
  mdl = GBoost_fit(X[idx.train,], Y[idx.train], 
                   group, total_steps=50000, step_size=c(1e-2,1e-2),
                   adj_var = 999, stop_tol=-1e-7, gamma = 0.1, 
                   lasso_lambda = 0.0314, weighted = 'n')
  elapsed = (proc.time()-start)["elapsed"]
  
  pred = X[idx.test,] %*% mdl$beta
  Y_true = Y[idx.test]
  if (length(idx.test)>1) {
    mse = MSE(pred, Y_true)
    R2 = Rsqr(pred, Y_true, mean(Y[idx.train]))
    results = list(mse, R2, mdl$beta, mdl$group_beta, elapsed)
    names(results) = c("mse", "R2", "beta", "group_beta", "elapsed")
  } else {
    results = list(pred, mdl$beta, mdl$group_beta, elapsed)
    names(results) = c("pred", "beta", "group_beta", "elapsed")  
  }
  return(results)
}
lmreg <- function (idx.test, X, Y, reg = "lasso") {
  if (reg == "lasso") {
    alp = 1
  } else if (reg == "ridge") {
    alp = 0
  } else {
    alp = seq(0,1,0.1)
  }
  idx.train = c(1:nrow(X))[!(c(1:nrow(X)) %in% idx.test)]
  # registerDoParallel(cores)
  start = proc.time()
  mdl <- cv.glmnet(X[idx.train,], Y[idx.train], alpha=alp, parallel = FALSE)
  elapsed = (proc.time()-start)["elapsed"]
  # stopImplicitCluster()
  beta = as.vector(stats::coef(mdl, s="lambda.min"))[-1]
  pred = predict(mdl, X[idx.test,], s="lambda.min")
  Y_true = Y[idx.test]
  if (length(idx.test)>1) {
    mse = MSE(pred, Y_true)
    R2 = Rsqr(pred, Y_true, mean(Y[idx.train]))
    results = list(mse, R2, beta, elapsed)
    names(results) = c("mse", "R2", "beta", "elapsed")
  } else {
    results = list(pred, beta, elapsed)
    names(results) = c("pred", "beta", "elapsed")
  }
  return(results)
}
KRreg <- function(idx.test, X, Y, lamda) {
  idx.train = c(1:nrow(X))[-idx.test]
  start = proc.time()
  alpha = solve(lamda * diag(dim(X[idx.train,])[1]) + X[idx.train,] %*% t(X[idx.train,])) %*% Y[idx.train]
  w = t(X[idx.train,]) %*% alpha
  pred = X[idx.test,] %*% w
  elapsed = (proc.time()-start)["elapsed"]
  Y_true = Y[idx.test]
  mse = MSE(pred, Y_true)
  R2 = Rsqr(pred, Y_true, mean(Y[idx.train]))
  return(list(mse=mse, R2=R2, beta=as.vector(w), elapsed=elapsed))
}

# # betaMat.group = matrix(data=0, nrow = nodes, ncol = nodes)
# # betaMat = matrix(data=0, nrow = nodes, ncol = nodes)
# # betaMat.group[ind.tril] = mdl$group_beta
# # betaMat[ind.tril] = mdl$beta
# # write.csv(betaMat.group, file.path(rootPath, 'beta_group_z.csv'), row.names = FALSE)
# # write.csv(betaMat, file.path(rootPath, 'beta_z.csv'), row.names = FALSE)


############################################################
###               k-fold cross-validation               ###
kfoldcv <- function(fc, g_efa, group, nfolds = 5){
  # destroy networks' topological structure
  surr = foreach(i=1:nrow(fc), .inorder=TRUE, .combine='rbind') %do% {
    order = sample(ncol(fc))
    tmp = fc[i, order]
    return(tmp)
  }
  surr = scale(surr)
  g_efa = scale(g_efa)
  
  R2 = mse = pred = beta = group_beta = elapsed = list()
  
  fold = createFolds(sample(nrow(surr)), k=nfolds)
  loocv = ifelse(nfolds==nrow(surr), TRUE, FALSE)
  
  # Kernal Ridge regression
  R2$KRreg = mse$KRreg = elapsed$KRreg = pred$KRreg = c()
  beta$KRreg = matrix(data = NA, nrow = length(fold), ncol = ncol(fc))
  # registerDoParallel(90)
  results <- foreach(i=1:length(fold), .inorder = TRUE) %do%
    {KRreg(fold[[i]], fc, g_efa, lamda = 0.01)}
  stopImplicitCluster()
  for (i in 1:length(fold)) {
    if (loocv) {
      pred$KRreg[i] = results[[i]]$pred
    } else {
      R2$KRreg[i] = results[[i]]$R2
      mse$KRreg[i] = results[[i]]$mse
    }
    beta$KRreg[i,] = t(results[[i]]$beta)
    elapsed$KRreg[i] = results[[i]]$elapsed
  }
  if (loocv) {
    R2$KRreg = Rsqr(pred$KRreg, scale(g_efa))
    mse$KRreg = sum((pred$KRreg-scale(g_efa))**2)/(length(pred$KRreg)-1)
  }
  
  # Scalar-on-network regression
  R2$SNreg = mse$SNreg = pred$SNreg = elapsed$SNreg = c()
  beta$SNreg = group_beta$SNreg = matrix(data = NA, nrow = length(fold), ncol = ncol(surr))
  # registerDoParallel(90)
  results <- foreach(i = 1:length(fold), .inorder = TRUE, .packages = c("GBoost")) %do% 
    {SNreg(fold[[i]], surr, g_efa, group)}
  # stopImplicitCluster()
  for (i in 1:length(results)) {
    if (loocv) {
      pred$SNreg[i] = results[[i]]$pred
    } else {
      R2$SNreg[i] = results[[i]]$R2
      mse$SNreg[i] = results[[i]]$mse
    }
    beta$SNreg[i,] = t(results[[i]]$beta)
    group_beta$SNreg[i,] = t(results[[i]]$group_beta)
    elapsed$SNreg[i] = results[[i]]$elapsed
  }
  if (loocv) {
    R2$SNreg = Rsqr(pred$SNreg, scale(g_efa))
    mse$SNreg = sum((pred$SNreg-scale(g_efa))**2)/(length(pred$SNreg)-1)
  }
  
  
  # Lasso regression
  R2$lasso = mse$lasso = pred$lasso = elapsed$lasso = c()
  beta$lasso = group_beta$lasso = matrix(data = NA, nrow = length(fold), ncol = ncol(surr))
  # registerDoParallel(90)
  results <- foreach(i=1:length(fold), .packages=c("glmnet")) %do% 
    {lmreg(fold[[i]], surr, g_efa, reg = "lasso")}
  # stopImplicitCluster()
  for (i in 1:length(results)) {
    if (loocv) {
      pred$lasso[i] = results[[i]]$pred
    } else {
      R2$lasso[i] = results[[i]]$R2
      mse$lasso[i] = results[[i]]$mse
    }
    beta$lasso[i,] = t(results[[i]]$beta)
    elapsed$lasso[i] = results[[i]]$elapsed
  }
  if (loocv) {
    R2$lasso = Rsqr(pred$lasso, scale(g_efa))
    mse$lasso = sum((pred$lasso-scale(g_efa))**2)/(length(pred$lasso)-1)
  }
  
  # Ridge regression
  R2$ridge = mse$ridge = elapsed$ridge = pred$ridge = c()
  beta$ridge = group_beta$ridge = matrix(data = NA, nrow = length(fold), ncol = ncol(surr))
  # registerDoParallel(90)
  results <- foreach(i=1:length(fold), .packages=c("glmnet")) %do% 
    {lmreg(fold[[i]], surr, g_efa, reg = "ridge")}
  # stopImplicitCluster()
  for (i in 1:length(fold)) {
    if (loocv) {
      pred$ridge[i] = results[[i]]$pred
    } else {
      R2$ridge[i] = results[[i]]$R2
      mse$ridge[i] = results[[i]]$mse
    }
    beta$ridge[i,] = t(results[[i]]$beta)
    elapsed$ridge[i] = results[[i]]$elapsed
  }
  if (loocv) {
    R2$ridge = Rsqr(pred$ridge, scale(g_efa))
    mse$ridge = sum((pred$ridge-scale(g_efa))**2)/(length(pred$ridge)-1)
  }
  stopImplicitCluster()
  return(list(R2=R2, mse=mse, beta=beta, group_beta=group_beta, elapsed=elapsed))
}

registerDoParallel(50)
k = 10
results <- foreach(i = 1:50, .packages = c("GBoost", "glmnet")) %dopar%
  {kfoldcv(fc, df$g_efa_decon, group, nfolds = k)}
stopImplicitCluster()
loocv = ifelse(k==nrow(fc), 1, 0)
# sort results
for (assess in c("R2", "mse", "beta", "group_beta", "elapsed")) {
  assign(assess, list())
  for (mdl.name in c("SNreg", "lasso", "ridge", "KRreg")) {
    if ((assess=="group_beta") && mdl.name != "SNreg") {next}
    param = c()
    for (i in 1:length(results)) {
      if (i==1) {
        param = paste(param, sprintf("results[[%d]]$%s$%s", i, assess, mdl.name), sep="")
      } else {
        param = paste(param, sprintf("results[[%d]]$%s$%s", i, assess, mdl.name), sep=",")
      }
    }
    cmd = sprintf("%s$%s=rbind(%s)", assess, mdl.name, param)
    eval(parse(text=cmd))
  }
}
############################################################
###     Collect results from different regressions       ###
# var = c(ls(pattern = "R2"), ls(pattern = "mse"), ls(pattern = "beta"), ls("elapsed"))
filename = ifelse(loocv, "surr_anal_fisherz_loocv_u.Rdata", "surr_anal_fisherz_10foldcv_u.Rdata")
save(list = c("R2", "mse", "beta", "group_beta", "gp.parc", "elapsed"), file = filename)