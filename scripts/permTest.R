library(parallel)
library(doParallel)
library(foreach)

rootPath = dirname(getwd())
setwd(rootPath)
coeff.D = count = edge.sel = p = list()
file.name.temp = '####_anal_fisherz_10foldcv_u.Rdata'
figPath = file.path(rootPath, 'fig_u')
statsPath = file.path(rootPath, 'stats_u')
dir.create(figPath)
dir.create(statsPath)
for (mdl in c('SNreg', 'lasso', 'ridge', 'KRreg')) {
  for (type in c('fMRI', 'surr')) {
    file.name = gsub('####', type, file.name.temp)
    load(file.path(rootPath, file.name))
    
    ## calculate mean coefficient of determination for each repetition
    cmd = sprintf('coeff.D$%s = apply(R2$%s, 1, mean)',
                  ifelse(type == 'fMRI', 'emp', 'null'),
                  mdl)
    eval(parse(text = cmd))
    if (mdl == 'ridge' | mdl == 'KRreg') {
      next
      } else {
      # calculate mean selected times for each repetition
      k = 10 # number of folds in cross-validation
      rep_time = 50 # times of repetition
      cmd = sprintf(
        'count$%s = apply(ifelse(beta$%s!=0, 1, 0), 2, tapply, rep(1:rep_time,each=k), sum)',
        ifelse(type == 'fMRI', 'emp', 'null'),
        mdl
      )
      eval(parse(text = cmd))
      if (type == 'surr') next
      # check if each selected edge are all negative or positive across folds
      cmd = sprintf('NP = apply(beta$%s, 2, function(X) {
                      tmp = X[X != 0]
                      if (length(tmp) == 0) {
                        NP = 0
                      } else if(all(tmp < 0) | all(tmp > 0)) {
                        NP = ifelse(all(tmp < 0), -1, 1)
                      } else {
                        NP = 999
                      }
                      return(NP)
                    })', 
                    mdl)
      eval(parse(text = cmd))
    }
  }
  ## permutation test of coefficient of determination
  data.c = c(coeff.D$emp, coeff.D$null)
  idx.treat = c(rep(1, length(coeff.D$emp)), rep(0, length(coeff.D$null)))
  dist.obs = diff(by(data.c, idx.treat, mean))
  dist.per = replicate(1000, diff(by(data.c, sample(idx.treat), mean)))
  digitDetect <- function(x, i=0) {
    while (abs(x)<10^-i) {
      i = i+1
    }
    return(i)
  }
  round_exp <- function(x, digits) {
    y = round(x,digits = digits)
    if (abs(y)<abs(x)) {
      y = ifelse(y<0, y-10^-digits, y+10^-digits)
    }
    return(y)
  }
  bound.lower = round_exp(min(dist.per, dist.obs), digits = digitDetect(min(dist.per, dist.obs)))
  bound.upper = round_exp(max(dist.per, dist.obs), digits = digitDetect(max(dist.per, dist.obs)))
  svg(file.path(figPath, sprintf('coeffD_%s.svg', mdl)))
  hist(
    dist.per,
    xlim = c(bound.lower, bound.upper),
    col = 'black',
    breaks = 100,
    main = expression(R ^ 2),
    xlab = NULL
  )
  abline(v = dist.obs, col = 'red', lwd = 3)
  dev.off()
  # p = length(which(dist.per>dist.obs))/length(dist.per)
  
  
  ## permutation test for edge selection
  if (mdl == 'ridge' | mdl == 'KRreg') next
  data.c = rbind(count$emp, count$null)
  idx.treat = c(rep(1, dim(count$emp)[1]), rep(0, dim(count$null)[1]))
  ncluster = 50
  nperm = 1000 # number of permutation test
  alpha = 0.05 # confidence coefficient
  cl <- makeCluster(ncluster)
  tmp = parApply(cl, data.c, 2, by, idx.treat, mean)
  dist.obs = parApply(cl, tmp, 2, diff)
  stopCluster(cl)
  registerDoParallel(ncluster)
  # dist.per = replicate(nperm, apply(apply(data.c, 2, by, sample(idx.treat), mean), 2, diff))
  bapply <- function(x, group, func)
    return(by(x, sample(group), func))
  dist.per = foreach(i = 1:nperm,
                     .inorder = FALSE,
                     .combine = 'rbind') %dopar% {
                       return(t(apply(
                         apply(data.c, 2, bapply, idx.treat, mean), 2, diff
                       )))
                     }
  stopImplicitCluster()
  cl <- makeCluster(ncluster)
  cmp <- function(vec1, vec2) vec1 >= vec2
  flag = ifelse(t(apply(dist.per, 1, cmp, dist.obs)), 1, 0)
  cmd = sprintf('p$%s = parApply(cl, flag, 2, sum) / nperm', mdl)
  eval(parse(text = cmd))
  stopCluster(cl)
  cmd = sprintf('edge.sel$%s = p$%s < alpha', mdl, mdl)
  eval(parse(text = cmd))
  
  nodes = 400
  ind.tril = lower.tri(matrix(data = TRUE, nrow = nodes, ncol = nodes))
  tmp = matrix(data = 0, nrow = nodes, ncol = nodes)
  cmd = sprintf('tmp[ind.tril] = dist.obs * edge.sel$%s * NP 
        tmp = t(tmp)
        tmp[ind.tril] = dist.obs * edge.sel$%s * NP', mdl, mdl)
  eval(parse(text = cmd))
  write.csv(tmp,
            file.path(statsPath, sprintf('dist_obs_%s.csv', mdl)),
            row.names = FALSE)
  write.csv(dist.per,
            file.path(statsPath, sprintf('dist_per_%s.csv', mdl)),
            row.names = FALSE)
}
write.csv(edge.sel,
          file.path(statsPath, 'edge_sel.csv'),
          row.names = FALSE)
write.csv(p,
          file.path(statsPath, 'p.csv'),
          row.names = FALSE)
