library(dplyr)
library(data.table)
library(tidyr)
library(ggplot2)


removeNonly <- function(x){
  PSI<-x %>% dplyr::select(!matches("Q$")) %>% 
    pivot_longer(-c(GENE,EVENT,COORD,LENGTH,FullCO,COMPLEX),names_to = "sample",values_to = "PSI",values_drop_na = T)
  QC<-x %>% dplyr::select(matches("Q$"),EVENT) %>% 
    pivot_longer(-EVENT,names_to = "sample",values_to = "QC",values_drop_na = T) %>%
    mutate(sample=gsub(pattern="-Q|.Q",replacement="",sample))
  PSI %>% left_join(QC, by=c("EVENT","sample")) %>% mutate(PSI=ifelse(grepl(pattern="^N",QC),NA,PSI)) %>%
    pivot_wider(id_cols = c(GENE,EVENT,COORD,LENGTH,FullCO,COMPLEX),names_from = "sample",values_from = "PSI",values_fill = NA)
}
filetable<-file.choose()
names<-fread(filetable,sep = "\t",nrows = 0)
inctabl<-fread(cmd = paste0("fgrep 'HsaEX' ",gsub(" ","\\ ",filetable,fixed = T)),sep="\t",header=F)
colnames(inctabl)<-colnames(names)

inctabl<-inctabl %>% removeNonly() %>%
  pivot_longer(-c(GENE,EVENT,COORD,LENGTH,FullCO,COMPLEX), names_to = "SampleName",
               values_to = "PSI",values_drop_na = TRUE)
