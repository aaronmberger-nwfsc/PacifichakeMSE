###### Initialize the operating model ######
library(TMB)
library(dplyr)
library(reshape2)
library(ggplot2)
library(scales)
library(dplyr)
library(r4ss)
library(RColorBrewer)
library(PacifichakeMSE)
library(patchwork)

# 2018 assessment data
mod <- SS_output('inst/extdata/SS32018/', printstats=FALSE, verbose = FALSE) # Read the true selectivity

# Set true for printing to file
plot.figures = TRUE

# Load surveys per country (not available in SS3 file)
survey.obs <- read.csv('inst/extdata/survey_country.csv')
survey.ac <- read.csv('inst/extdata/ac_survey_country.csv')

# Age distribution in catch per country
ac.data <- read.csv('inst/extdata/FleetAgeComp_byNation.csv' )
catch.ac.obs <- read.csv('inst/extdata/age_in_catch_obs.csv') # This data is outdated (last year is wrong)


nparms <- 5
movemax.parms <- seq(0.1,0.9, length.out = nparms)
movefifty.parms <- seq(1,10, length.out = nparms)


yr.future <- 2

df <- load_data_seasons(nseason = 4, nspace = 2, bfuture = 0.5, movemaxinit = 0.35, movefiftyinit =6,
                        yr_future = yr.future, myear = 2018) # Prepare data for operating model

df.2 <- load_data_seasons(nseason = 4, nspace = 2, bfuture = 0.5, movemaxinit = 0.35, movefiftyinit =6,
                          yr_future = yr.future,
                          sel_hist = 0, myear = 2018) # Prepare data for operating model


df$surveyseason <- 3
sim.data <- run.agebased.true.catch(df)
sim.data_nosel <- run.agebased.true.catch(df.2)

Catch.future <- c(df$Catch, rep(206507.8, yr.future)) # Project MSY
df$Catch <- Catch.future
r.succes <- matrix(NA, length(movemax.parms)*length(movefifty.parms))
AC.catch.tot <- AC.survey.tot <- array(NA, dim = c(df$age_maxage,df$nyear,
                                                   df$nspace,length(movemax.parms)*length(movefifty.parms)))
survey.ml <- array(NA,dim = c(df$nyear,df$nspace,length(movemax.parms)*length(movefifty.parms)))

standard.move <- runfuture_OM(df, 1)
standard.move_sel <- runfuture_OM(df.2, 1)

ac.survey.tot <- survey.ac %>%
  group_by(year, country) %>%
  summarise(AC.mean = sum(survey*age))

AC.survey <- data.frame(AC.mean = c(standard.move$survey.AC[,1],standard.move$survey.AC[,2]),
                        country = rep(c('CAN','USA'), each = df$nyear), year = rep(df$years,2))


tag.x <- .07

p.AC.survey <- ggplot(AC.survey, aes(x = year, y= AC.mean, color = country, linetype = country))+
  geom_line(size = 1)+theme_classic()+
  geom_line(data = ac.survey.tot, size = .5, show.legend = FALSE, linetype = 1)+
  geom_point(data = ac.survey.tot, show.legend = FALSE)+  
  scale_x_continuous(
    name = '',
    limit = c(1965,2018), 
    breaks = seq(1970,2020, by = 10))+
  scale_color_manual(values = c('darkred','blue4'), labels = c('CAN','US'))+
  scale_linetype_manual(values = c(1,2), labels = c('CAN',"US"))+
  theme(
        legend.position = 'top',
        legend.title = element_blank(),
        axis.text.y = element_text(size = 8),
        axis.text.x = element_blank(),
        axis.title.x =  element_blank(),
        axis.title.y = element_text(size =10),
        legend.text = element_text(size = 10),
        legend.key.width = unit(1.1,"cm"),
        legend.background = element_blank(),
        plot.tag.position = c(tag.x, 0.90),
        plot.tag = element_text(size = 8),
        legend.direction="horizontal"
  )+
  scale_y_continuous('Mean age \nin survey')+
  labs(tag = "(A)")
  
  # annotate('text',x =  1965, y= 10, label = '(A)')+
  # geom_text(aes(x =))
p.AC.survey

#
# if(plot.figures == TRUE){
#   png(filename = 'results/Figs/AC_survey.png', width = 16, height = 12, res = 400, units = 'cm')
#   print(p.AC.survey)
#   dev.off()
# }



# plot the biomasses in the two countries
df.plot.sim <- data.frame(survey = c(standard.move$survey.space[1,],standard.move$survey.space[2,]),
                          source = 'OM',
                          years = rep(df$years,2),
                          country = rep(c('CAN','USA'), each = length(df$years)))
df.obs <- data.frame(survey = c(survey.obs$survey[survey.obs$country == 'CAN'],survey.obs$survey[survey.obs$country == 'USA']),
                     source = 'observation',
                     years = survey.obs$year,
                     country = rep(c('CAN','USA'), each = length(survey.obs$year)/2))

df.plot <- rbind(df.plot.sim,df.obs)

p1 <- ggplot(df.plot.sim, aes( x=  years, y = survey*1e-4, color = country, linetype = country))+
  theme_classic()+geom_line(size = 1)+
  geom_line(data = df.obs, size = 0.5, show.legend = FALSE, linetype = 1)+
  geom_point(data = df.obs, show.legend = FALSE)+
  scale_linetype_manual(values = c(1,2))+
  scale_color_manual(values = c('darkred','blue4'))+
  scale_y_continuous('Survey biomass \n(thousand tons)')+
  scale_x_continuous('year',limit = c(1965,2018), breaks = seq(1970, 2020, by = 10))+
  theme(legend.position = 'none',
        legend.background = element_rect(fill=NA),
        legend.title = element_blank(),
        axis.text.y = element_text(size = 8),
        axis.text.x = element_text(size =8),
        axis.title.y = element_text(size = 10),
        legend.text = element_text(size = 10),
        plot.tag.position = c(tag.x, 0.98),
        plot.tag = element_text(size = 8)
  )+
  labs(tag = "(C)")


p1

# Calculate the median predictive error
df.calc <- df.plot.sim[df.plot.sim$years %in% df.obs$years,]

df.EE <- data.frame(EE = (df.obs$survey-df.calc$survey)/df.obs$survey,  country = df.calc$country,
                    year = df.calc$years)

p.EE <- ggplot(df.EE, aes(x = year, y = EE, color = country))+geom_line()+theme_classic()+geom_hline(aes(yintercept = 0))+geom_point()+
  coord_cartesian(ylim = c(-3,1))
print(median(df.EE$EE[df.EE$country == 'CAN']))
print(median(df.EE$EE[df.EE$country == 'USA']))

p1/p.EE
# if(plot.figures == TRUE){
#   png(filename = 'results/Figs/Biomass_survey.png', width = 16, height = 12, res = 400, units = 'cm')
#   print(p1)
#   dev.off()
# }
# Check the fleet age comps again
names(ac.data)[names(ac.data) %in% paste('X',1:15, sep ='')] <- 1:15

ac.tot <- melt(ac.data, id.vars = c('Year', 'Country','Nsamples'), measure.vars = paste(1:15),
               variable.name = 'age')
ac.tot$age <- as.numeric(ac.tot$age)

ac.df <- ac.tot %>%
  group_by(Country, Year) %>%
  summarise(ac = sum(age*value))
surv.tot <- survey.obs %>%
  group_by(year) %>%
  summarise(survey = sum(survey))
catch.model <- data.frame(year = rep(df$years,2),
                          Country = rep(c('USA','CAN'), each = df$nyear),
                          am = c(standard.move$catch.AC[,2],standard.move$catch.AC[,1]))
catch.model <- data.frame(year = rep(df$years,2),
                          Country = rep(c('USA','CAN'), each = df$nyear),
                          am = c(standard.move$catch.AC[,2],standard.move$catch.AC[,1]))

ac.df$Country[ac.df$Country == 'Can'] <- 'CAN'

p.AC.catch <- ggplot(ac.df, aes(x = Year, y = ac, color = Country, linetype = Country))+
  geom_line(size =0.5, linetype = 1)+
  geom_point()+
  geom_line(data = catch.model, aes(x = year, y= am, color = Country), size = 1)+theme_classic()+
  scale_x_continuous(limit = c(1965,2018), breaks = seq(1970, 2020, by = 10), minor_breaks = 1965)+
  scale_color_manual(values = rep(c('darkred','blue4'), each = 1))+
  scale_y_continuous('Mean age \nin catch')+
  scale_linetype_manual(values = c(1,2))+
  theme(legend.position = 'none',
        axis.title.x = element_blank(),
        axis.title.y = element_text(size = 10),
        axis.text.x = element_blank(),
        legend.text = element_text(size = 10),
        axis.text.y = element_text(size = 8),
        plot.tag.position = c(tag.x, 0.98),
        plot.tag = element_text(size = 8)
        )+
  #annotate('text',x =  1965, y= 10, label = '(B)')
  labs(tag = "(B)")

if(plot.figures == TRUE){
  png(filename = 'results/Figs/AC_catch.png', width = 16, height = 8, res = 400, units = 'cm')
  print(p.AC.catch)
  dev.off()

}

# cowplot::plot_grid(p1,p.AC.catch, p.AC.survey, ncol = 2, nrow = 2,align = 'hv',labels = 'auto',
#                    rel_widths = c(1,0.5,0.5))

# Try using Patchwork
if(plot.figures == TRUE){
  png(filename = 'results/Climate/Publication/Resubmission/Figure4.png', width = 8, height = 12, res = 400, units = 'cm')
  print((p.AC.survey / p.AC.catch / p1))
  dev.off()


  pdf(file = 'results/Climate/Publication/Resubmission/Figure45.pdf', width = 8/cm(1), height = 14/cm(1))
  print((p.AC.survey / p.AC.catch / p1))
  #   )
  # 
  dev.off()




}

# Plot the movement rates
df.movement <- data.frame(age = rep(df$age, 8), movement = NA, country = rep(c('CAN','USA'), each = df$nage),
                          season = rep(1:4, each = df$nage*2))
df.movement$age[df.movement$country == 'CAN'] <-  df.movement$age[df.movement$country == 'CAN'] # For plotting
for(i in 1:df$nseason){
  mm.tmp <- df$movemat[,,i,1]

  df.movement[df.movement$season == i & df.movement$country == 'USA',]$movement <- mm.tmp[2,]
  df.movement[df.movement$season == i & df.movement$country == 'CAN',]$movement <- mm.tmp[1,]
}

# Text for publication
ann_mm <- data.frame(age = 6,movement = 0.55, season = 1, country = 'USA')
ann_return <- data.frame(age = 10,movement = 0.50, season = 4, country = 'USA')

# Rename for plot
df.movement$country[df.movement$country == 'USA'] <- 'North movement'
df.movement$country[df.movement$country == 'CAN'] <- 'South movement'

#png('survey_comps.png', width = 16, height = 10, res= 400, unit = 'cm')
p.move <-ggplot(df.movement, aes(x = age, y = movement, color = country))+
  facet_wrap(~season)+theme_classic()+ 
  geom_hline(data = data.frame(season = 1),aes(yintercept = max(df.movement$movement[df.movement$country == 'North movement' & 
                                                                                              df.movement$season == 1])),
                                                  linetype = 2)+
  geom_line(size = 1.45, aes(linetype = country))+
  scale_y_continuous(limit = c(0,1),name = expression(paste('movement rate, ',omega)))+
  scale_color_manual(values = c('darkred','blue4'))+
  theme(legend.title = element_blank(),legend.position = c(0.15,0.35), legend.direction = 'vertical',
        legend.background = element_rect(fill=NA))+
  scale_x_continuous(limits = c(0,20))+
 
  geom_text(data = ann_mm, label = expression(paste('max movement rate, ',kappa)), color = 'black')+
  geom_text(data = ann_return, label = expression(paste('return rate, ',kappa['return'])), color = 'black')+
  geom_segment(data = data.frame(x= 4, y= 0.47, xend = 4, yend = 0.38, season = 1),
               aes(x=x,  y= y, xend = xend, yend=yend), color = 'black',
                arrow = arrow(length = unit(0.1, "inches"))
               )+
  geom_segment(data = data.frame(x= 10, y= 0.55, xend = 10, yend = 0.80, season = 4),
               aes(x=x,  y= y, xend = xend, yend=yend), color = 'black',
               arrow = arrow(length = unit(0.1, "inches"))
  )

p.move

if(plot.figures == TRUE){
png(filename = 'results/Climate/Publication/Resubmission/Figure1.png', width = 16, height = 10, res = 400, units = 'cm')
print(p.move)
dev.off()

pdf(file = 'results/Climate/Publication/Resubmission/Figure1.pdf', width = 16/cm(1), height = 10/cm(1))
print(p.move)
dev.off()




}

#windows(width = 16/cm(1), height = 10/cm(1))

# plot_grid(p1,p.AC.survey, nrow = 2, align = 'hv',
#           label_x = c(0.95,0.95),
#           label_y = c(0.98,0.98),
#           labels = 'auto')
# dev.off()
if(plot.figures == TRUE){
  png(filename = 'results/Figs/Biomass_survey.png', width = 16, height = 10, res = 400, units = 'cm')
  print(plot_grid(p1,p.AC.survey, nrow = 2, align = 'hv',
                  label_x = c(0.95,0.95),
                  label_y = c(0.98,0.98),
                  labels = 'auto'))
  dev.off()
}
# From the asssessment
df.ass <- data.frame(survey = mod$cpue$Exp,source = 'assessment',years = mod$cpue$Yr, country ='Both')

df.tot <- rbind(df.plot,df.ass) %>%
  group_by(years, source) %>%
  summarise(survey = sum(survey))
cols <- brewer.pal(6, 'Dark2')

df.survey <- data.frame(years = df$years[df$flag_survey == 1],
                        source = 'Survey data',
                        survey = df$survey$x[df$flag_survey == 1],
                        survsd=  sqrt(df$survey$x[df$flag_survey == 1]^2*exp(df$survey_err[df$flag_survey == 1]+
                                                                               exp(df$parms$logSDsurv)-1))
)
df.tot$survsd <- NA


p2 <- ggplot(data = df.survey, aes(x = years, y = survey/1e6, color = source))+
  geom_point(size = 3, col = cols[3])+
  geom_line(data = df.tot[which(df.tot$source =='OM'),], size =1.5, col = cols[1])+
  geom_line(data = df.tot[which(df.tot$source =='assessment'),], size =1.2, col = cols[2], linetype = 2)+
  theme_classic()+theme(legend.position = 'none')+
  geom_errorbar(aes(ymin=(survey-survsd)/1e6, ymax=(survey+survsd)/1e6), color = cols[3])+
  scale_y_continuous(limit = c(0,5), name = 'survey biomass \n(million t)')+
  scale_x_continuous(name = 'year', limit = c(1994,2019),
                     labels = c(2000,2010),
                     breaks = c(2000,2010))

p2


if(plot.figures == TRUE){

  png(file = 'results/Figs/survey_total.png', width = 8*2, height = 7, res =400, units = 'cm')
  print(p2)
  dev.off()

}



p.AC.catch <- ggplot(catch.ac.obs, aes(x = year, y= am, color = Country))+geom_line(size = 1, linetype = 2)+theme_classic()+
  geom_line(data = catch.model, linetype = 1, size = 1)+geom_point()+
  scale_color_manual(values = c('darkred','blue4'))+
  theme(legend.position = 'none')+scale_y_continuous('mean age')

p.AC.catch

catch.model.2 <- data.frame(year = rep(df$years,4),
                            Country = rep(c('USA','CAN','US no sel','Can no sel'), each = df$nyear),
                            am = c(standard.move$catch.AC[,2],standard.move$catch.AC[,1],
                                   standard.move_sel$catch.AC[,2], standard.move_sel$catch.AC[,1]))

cols <- LaCroixColoR::lacroix_palette('PinaFraise',n = 4)

p.AC.catch <- ggplot(catch.ac.obs, aes(x = year, y= am, color = Country))+geom_line(size = 1, linetype = 2)+theme_classic()+
  geom_line(data = catch.model.2, linetype = 1, size = 1)+geom_point()+
  scale_color_manual(values = rep(c('darkred','blue4'), each = 2))+
  theme()+scale_y_continuous('mean age')

p.AC.catch



if(plot.figures == TRUE){
  png(filename = 'results/Figs/AC_catch.png', width = 16, height = 8, res = 400, units = 'cm')
  print(p.AC.catch)
  dev.off()

}

#surv.model <- data.frame(year = df$years, )

# Fishing mortality per area

F.plot <- apply(sim.data$Fout, FUN = sum, MARGIN = c(1,3))
F0.assessment <- read.csv('inst/extdata/F0.csv')

df.F <- data.frame(year = rep(df$years,2),
                   F0 = c(F.plot[,1],F.plot[,2]),
                   Country = rep(c('CAN','USA'), each = df$nyear))

p2 <- ggplot(df.F)+geom_col(aes(x = year, y = F0, fill = Country), position = position_dodge(width = 0.9))+
  scale_fill_manual(values = c('darkred','blue4'))+
  geom_line(data = data.frame(year = 1966:2018, F0 = F0.assessment$x),
            aes(x = year, y= F0), size = 1.5, color = 'black')+
  theme(legend.position = 'none')
p2


if(plot.figures == TRUE){
  png(filename = 'results/Figs/F_country.png', width = 16, height = 12, res = 400, units = 'cm')
  print(p2)
  dev.off()

}


if(plot.figures == TRUE){
  png(filename = 'results/Figs/Movement.png', width = 16, height = 12, res = 400, units = 'cm')
  print(p.move)
  dev.off()

}


# Youth distribution 
smalliest <- survey.ac[survey.ac$age %in% 2,] %>% group_by(year, country) %>% summarise(bio = sum(survey))

ggplot(smalliest, aes(x = year,  y = bio, color =country))+geom_line()+theme_bw()


# Plot 

