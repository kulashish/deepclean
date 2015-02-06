library(tau)
library(doParallel)
library(itertools)
library(qdap)
library(maps)
library(stringr)
source("cleanup_header.R")

# LOAD THE DATA FROM S3
data.source <- read.table(file='/home/ubuntu/test_framework_03.txt000.gz', sep='|', quote="", comment.char="", numerals="no.loss", col.names = c('transaction_id', 'description', 'merchant', 'random'), stringsAsFactors = F)

#GLOBAL
words <- readLines(system.file("stopwords", "english.dat", package = "tm"))
data(us.cities)
us.states <<- unique(us.cities$country.etc)
ncores <- 4
cl <- makePSOCKcluster(ncores)
registerDoParallel(cl)

#PRE-PROCESSING: STOP WORD AND EXTRA SPACE REMOVAL
data.source$clean_description <- foreach(m=isplitRows(data.source, chunks=ncores), .combine=c, .packages='tau') %dopar% 
    preprocess(m, words)

    words.freq.corpus       <- read.csv('freq_words_corpus.txt', header = F, stringsAsFactors = F)
    words.freq.tf           <- read.csv('freq-words-testframework.txt', header = F, stringsAsFactors = F)
    words.merchant          <- read.csv('merchant_words.txt', header = T, stringsAsFactors = F)
    word.classes            <- read.csv('word_classes.csv', header = T)
    valid_words             <<- c(words.freq.corpus$V2, words.freq.tf$V2, as.character(words.merchant$Word), as.character(word.classes$replace))

    data.source$generalized_description <- mysub(word.classes$pattern, word.classes$replace, word.classes$status, data.source$clean_description)

    data.source$generalized_description <- foreach(m=isplitRows(data.source, chunks=ncores), .combine=c, .packages=c('maps', 'stringr')) %dopar%
      georep(m$generalized_description)

      cities.list <- read.csv('us_places.txt', header=T, stringsAsFactors=F)$Word
      merchants.list <- words.merchant$Word
      data.source$geo_description <- foreach(m=isplitRows(data.source, chunks=ncores), .combine=c, .packages='qdap') %dopar%
        cityrep(m$generalized_description, cities.list, merchants.list)

	stopCluster(cl)

	cat('Number of transactions :', nrow(data.source), '\n')
	write.table(data.source, file='/home/ubuntu/test_framework_03_generalized.txt', sep = '|', quote = F)

