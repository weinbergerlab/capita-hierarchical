non_hierarchical_dir_func<-function(){
  model_string<-"
  model{
  
  for(i in 1:2){
  
  #Likelihood
  y[i, 1:14] ~ dmulti(p[i, 1:14], m[i])
  
  #Dirichlet Prior Distribution
  p[i, 1:14] ~ ddirch(epsilon[1:14])
  
  }
  
  #Serotype-Specific Vaccine Effects
  #100*(p_{no_vax} - p_{vax})/p_{no_vax}
  for(j in 1:13){
  sero_vax_effect[j] <- 100*(1 - p[2,j]/p[1,j])
  }
  
  #Overall Vaccine Effect
  overall_vax_effect <- 100*(1 - (1 - p[2,14])/(1 - p[1,14]))
  
  }
  "


##############################################################
#Model Fitting
##############################################################
inits1=list(".RNG.seed"=c(123), ".RNG.name"='base::Wichmann-Hill')
inits2=list(".RNG.seed"=c(456), ".RNG.name"='base::Wichmann-Hill')
inits3=list(".RNG.seed"=c(789), ".RNG.name"='base::Wichmann-Hill')

model_spec<-textConnection(model_string)
model_jags<-jags.model(model_spec, 
                       inits=list(inits1,inits2, inits3),
                       data=list('y' = y,
                                 'm' = m,
                                 'epsilon' = rep(0.02, times=14)),
                       n.adapt=10000, 
                       n.chains=3)

params<-c('overall_vax_effect',
          'sero_vax_effect')


##############################################
#Posterior Sampling
##############################################
posterior_samples<-coda.samples(model_jags, 
                                params, 
                                n.iter=100000)
posterior_samples.all<-do.call(rbind,posterior_samples)

###################################################
#POSTERIOR INFERENCE
###################################################
#post_means<-colMeans(posterior_samples.all)
post_means<-apply(posterior_samples.all, 2, median)
sample.labs<-names(post_means)
ci<-t(hdi(posterior_samples.all, credMass = 0.95))
ci<-matrix(sprintf("%.1f",round(ci,1)), ncol=2)
row.names(ci)<-sample.labs
post_means<-sprintf("%.1f",round(post_means,1))
names(post_means)<-sample.labs

st.labs<-as.character(unique(d1$st))

yrange<-range(ci)

overall.VE<-c(post_means[1], ci[1,])
st.VE<- cbind(post_means[-1], ci[-1,])


#install.packages('rmeta')
library(rmeta)
summary_data <- 
  structure(list(
    mean  = c(NA, NA,post_means[2:14],NA,post_means[1]), 
    lower = c(NA, NA,ci[2:14,1],NA,ci[1,1]),
    upper = c(NA, NA,ci[2:14,2],NA,ci[1,2]),
    .Names = c("mean", "lower", "upper"), 
    row.names = c(NA, -11L), 
    class = "data.frame"))

if (outcome.var=='n_s11_pp'){
  ci['sero_vax_effect[8]',]<-NA
  post_means['sero_vax_effect[8]']<-NA
}
tabletext<-cbind(
  c("", "Serotype", st.labs, NA, "All"),
  c("Vaccine", "(N=42240)", d1[,outcome.var][d1$vax==1], NA, sum(d1[,outcome.var][d1$vax==1])),
  c("Control", "(N=42256)",  d1[,outcome.var][d1$vax==0], NA, sum(d1[,outcome.var][d1$vax==0])),
  c("", "VE", paste0(post_means[2:14],'%'),NA,paste0(post_means[1],'%')),
  c("", "95% CrI",paste0('(', ci[2:14,1],'%, ',ci[2:14,2] ,'%',')') , 
    NA, paste0('(', ci[1,1],'%',', ' ,  ci[1,2],'%',')' ) )  
)
    
  
res.list<-list('tabletext'=tabletext, 'summary_data'=summary_data,'st.VE'=st.VE)
return(res.list)

}