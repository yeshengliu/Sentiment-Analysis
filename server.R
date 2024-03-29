library(shiny)

shinyServer(function(input, output, session) {
  CreateTextDataframe <- reactive( {              # Execute function based on input$typeInput
    if(input$typeInput == "Custom Text") {
      return(CustomText())
    } else if (input$typeInput == "Search Twitter") {
      return(GetTwitter())
    # } else if (input$typeInput == "Search Facebook") {
    #   return(GetFacebook())
    # } else if (input$typeInput == "Search Glassdoor") {
    #   return(GetGlassdoor())
    } else if (input$typeInput == "Search Reddit") {
      return(GetReddit())
    } else if (input$typeInput == "Upload File") {
      uploadfile.dataframe <- UploadFile()   # Load uploadfile
      text.dataframe <- ProcessUploadFile(uploadfile.dataframe) # Process uploadfile.dataframe based on user configuration in UI
    }
  })
  CustomText <- eventReactive(input$button, {     # Export custom text
    text.archieve <- input$custom.text.text %>% strsplit(";")
    keywords.count <- length(text.archieve[[1]])
    text.dataframe <- data.frame(       # Create an empty dataframe to store org.text
      keywords = character(),
      org.text = character()
    )
    text.archieve %<>% unlist()         # Convert list to vector
    text.archieve %<>% trimws()         # Remove leading, trailing whitespaces
    keywords.list <- rep("NA", keywords.count)
    text.dataframe <- data.frame(
      keywords = keywords.list,
      org.text = text.archieve
    )
    return(text.dataframe)
  })
  GetTwitter <- eventReactive(input$button, {    # Export Twitter data
    api_key <- ""
    api_secret <- ""
    access_token <- ""
    access_token_secret <- ""
    setup_twitter_oauth(api_key, api_secret)
    twitter.keywords <- unique(
      strsplit(input$twitter.text, ";")
    )  # return a List of 1
    keywords.count <- length(twitter.keywords[[1]])
    twitter.count <- input$twitter.num  # tweets to request from each query
    text.dataframe <- data.frame(       # Get tweets
      keywords = character(),
      org.text = character()
    )
    for (i in 1 : keywords.count) {
      text.archieve <- sapply(                        # text.archieve is a vector 
        searchTwitter(twitter.keywords[[1]][[i]],
                      lang ="en",
                      n = twitter.count,
                      resultType = "recent"
        ),
        function(x) x$getText()
      )
      keywords.list <- rep(twitter.keywords[[1]][[i]],
                           each = length(text.archieve)
      )
      text.dataframe <- rbind(text.dataframe,
                              data.frame(
                                keywords = keywords.list,
                                org.text = text.archieve
                              )
      )
    }
    return(text.dataframe)   # text.dataframe is a data frame with two columns: keywords, text
  })
  GetGlassdoor <- eventReactive(input$button, {    # Export Glassdoor data
    
  })
  GetReddit <- eventReactive(input$button, {
    reddit.keywords <- unique(
      strsplit(input$reddit.text, ";")
    )
    keywords.count <- length(reddit.keywords[[1]])
    reddit.count <- input$reddit.num
    text.dataframe <- data.frame(
      keywords = character(),
      org.text = character()
    )
    for (i in 1 : keywords.count) {
      post.archieve <- data.frame(                      # Create empty dataframe before loop
        date = character(),
        num_comments = numeric(),
        title = character(),
        subreddit = character(),
        URL = character()
      )
      page.number <- 1                                  # Set initial page 
      repeat{
        post.archieve <- rbind(
          post.archieve,
          reddit_urls(
            search_terms = reddit.keywords[[1]][[i]],    # Search by keyword i
            cn_threshold = 10,                           # Skip posts have less than 10 comments
            page_threshold = page.number,                # the number of page will be returned
            sort_by = "relevance"                        # Sort by comments
          )
        )
        if (nrow(post.archieve) >= reddit.count) {       # Loop until post.archieve gets enough records
          break
        }
        page.number <- page.number + 1
      }
      post.archieve <- sample_n(post.archieve,          # Delete excess rows
                                reddit.count
      )
      for (j in 1 : reddit.count) {
        post.archieve$org.text[j] <- paste(
          unlist(
            reddit_content( post.archieve$URL[j] )$comment
          ),
          collapse = " "
        )
      }
      keywords.list <- rep(reddit.keywords[[1]][[i]],
                           each = reddit.count
      )
      text.dataframe <- rbind(text.dataframe,
                              data.frame(
                                keywords = keywords.list,
                                org.text = post.archieve$org.text
                              )
      )
    }
    return(text.dataframe)
  })
  UploadFile <- eventReactive(input$button, {      # Export text from upload file
    inFile <- input$files
    
    datatable.archieve <- data.frame(                            # Load file as dataframe
      read.table(inFile$datapath,
                 header = input$header,
                 sep = input$sep,
                 quote = input$quote
      )
    )
    datatable.archieve$keywords <- rep(inFile$name,               # Attach filename to each row
                                       nrow(datatable.archieve)
                                       
    )
    return(datatable.archieve)
  })
  ProcessUploadFile <- function(datatable.archieve) {     # Drop unused columns from upload file
    # text.dataframe <- data.frame(
    #   keywords = character(),
    #   org.text = character()
    # )
    text.dataframe <- data.frame(
      keywords = datatable.archieve$keywords,
      org.text = as.character(datatable.archieve[[input$columns]])
    )
    return(text.dataframe)
  }
  #################################### Clean Text Function #######################################  
  CleanText <- function(some_txt) {      # Clean text function
    # remove html links
    some_txt <- gsub("http\\S+\\s*",
                     "",
                     some_txt)
    # remove retweet entities
    some_txt <- gsub("(RT|via)((?:\\b\\W*@\\w+)+)",
                     "",
                     some_txt)
    # remove at people
    some_txt <- gsub("@\\w+", 
                     "", 
                     some_txt)
    if(input$emoticon == TRUE) {                  # replace emotioncs with words
      some_txt <- replace_emoticon(some_txt)
    }
    # if(input$grading == TRUE) {                 # Replace grades like 'A+'
    #   some_txt <- replace_grade(some_txt)
    # }
    if(input$rating == TRUE) {                    # Replace ratings
      some_txt <- replace_rating(some_txt)
    }
    try.error <- function(x) {                    # "tolower error handling" function
      # create missing value
      y <- NA
      # tryCatch error
      try_error <- tryCatch(tolower(x), 
                            error = function(e) e)
      # if not an error
      if ( !inherits(try_error, "error") ) {
        y <- tolower(x)
      }
      # result
      return(y)
    }
    # lower case using try.error with sapply 
    some_txt <- sapply(some_txt, try.error)
    # remove NAs in some_txt
    some_txt <- some_txt[ !is.na(some_txt) ]
    names(some_txt) <- NULL
    myCorpus <- Corpus(VectorSource(some_txt))
    myCorpus <- tm_map(myCorpus, content_transformer(tolower))
    # myCorpus <- tm_map(myCorpus, removePunctuation)
    myCorpus <- tm_map(myCorpus, content_transformer(strip), char.keep = ".")    # Keep period
    myCorpus <- tm_map(myCorpus, removeNumbers)
    #Add words to be excluded from the list of stop words here
    exceptions <- c("not","nor","neither","never")
    my_stopwords <- setdiff(stopwords("en"), exceptions)
    myCorpus <- tm_map(myCorpus, removeWords, my_stopwords)
    myCorpus <- tm_map(myCorpus, stemDocument)
    some_txt_clean <- as.character(unlist(sapply(myCorpus, `[`, "content")))
    # remove trailing/leading spaces
    some_txt_clean <- str_trim(some_txt_clean)
    return(some_txt_clean)
  }
  create_wordcloud <- function(some_txt, ngram.min, ngram.max) {        # Create Wordcloud
    myCorpus = Corpus(VectorSource(some_txt))
    BigramTokenizer <- function(x) { 
      NGramTokenizer(x, Weka_control(min = ngram.min,
                                     max = ngram.max
      )
      )
    }
    tdm.bigram <- TermDocumentMatrix(myCorpus, 
                                     control = list(tokenize = BigramTokenizer))
    freq <- sort(rowSums(as.matrix(tdm.bigram)), decreasing = TRUE)
    freq.df <- data.frame(word = names(freq), 
                          freq = freq)
    return(freq.df)
  }
  ############################### Topic Modelling AND WORD FREQUENCIES#######################################
  
  topic_model <- function(final_txt, count.topic) {
    # Create DTM
    myCorpus <- Corpus(VectorSource(final_txt))
    DTM <- DocumentTermMatrix(myCorpus)
    rowTotals <- apply(DTM , 1, sum) #Find the sum of words in each Document
    DTM   <- DTM[rowTotals > 0, ] 
    #Compute word frequencies
    freq <- sort(colSums(as.matrix(DTM)), decreasing = TRUE) 
    wf <- data.frame(word = names(freq), 
                     freq = freq)   
    # Set parameters for Gibbs sampling
    burnin <- 4000
    iter <- 2000
    thin <- 500
    seed <- list(2003, 5, 63, 100001, 765)
    nstart <- 5
    best <- TRUE
    #Number of topics
    #Run LDA using Gibbs sampling
    ldaOut <- LDA(DTM,as.numeric(count.topic))
    #Get top 5 words for each topic
    top_terms <- as.data.frame(terms(ldaOut,10))
    return(top_terms)
  }
  #################################### Dataframe functions ###############################################
  column.name.vector <- function(inFile) {     # Return upload file header once file is uploaded
    datatable.archieve <- data.frame(          
      read.table(inFile$datapath,
                 header = input$header,
                 sep = input$sep,
                 quote = input$quote
      )
    )
    return(colnames(datatable.archieve))
  }
  SentimentPolarity <- function(sentiment) {    # Required for CleanDataframe & ConvertDataframe
    if (sentiment > 0) {
      return("positive")
    } else if (sentiment == 0) {
      return("neutral")
    } else {
      return("negative")
    }
  }
  CleanDataframe <- function(text.dataframe) {    # Clean text.dataframe and attach sentiment value
    text.dataframe$clean.text <- CleanText(text.dataframe$org.text)
    text.dataframe$sentiment <- sentiment_by(text.dataframe$clean.text)$ave_sentiment
    text.dataframe$sentiment <- text.dataframe$sentiment
    text.dataframe$sentiment.pol <- lapply(text.dataframe$sentiment, SentimentPolarity)
    return(text.dataframe)
  }
  ConvertDataframe <- function(text.dataframe,    # Add sentiment polarity
                               rule = c("sentiment", "positive", "negative", "neutral")) {
    if (rule == "sentiment") {
      sentiment.dataframe <- data.frame(element_id = numeric(),     # Definition of sentiment.dataframe
                                        word_count = numeric(),
                                        sd = numeric(),
                                        ave_sentiment = numeric(),
                                        org.text = character(),
                                        clean.text = character(),
                                        keywords = character()
      )
      for (i in 1:length(unique(text.dataframe$keywords))) {
        text.dataframe.subset <- subset(text.dataframe,
                                        keywords == unique(text.dataframe$keywords)[i]
        )
        sentiment.dataframe.temp <- sentiment_by(text.dataframe.subset$clean.text)
        sentiment.dataframe.temp$org.text <- text.dataframe.subset$org.text
        sentiment.dataframe.temp$clean.text <- text.dataframe.subset$clean.text
        sentiment.dataframe.temp$keywords <- rep(unique(text.dataframe$keywords)[i],
                                                 nrow(sentiment.dataframe.temp))
        sentiment.dataframe <- rbind(sentiment.dataframe,
                                     sentiment.dataframe.temp
                                     )
      }
      sentiment.dataframe$sentiment.pol <- lapply(sentiment.dataframe$ave_sentiment, SentimentPolarity)
      sentiment.dataframe$sentiment.pol %<>% unlist() %<>% as.factor()
      return(sentiment.dataframe)
    }
    else {
      text.subset.dataframe <- subset(text.dataframe,
                                      text.dataframe$sentiment.pol == rule    # Split text.dataframe based on sentiment level
      )
      return(text.subset.dataframe)
    }
  }
  #################################### Actual code part of the app#########################################
  observeEvent(!is.null(input$files), {           # Update select column field once file is uploaded
    if (!is.null(input$files)) {
      inFile <- input$files
      updateSelectInput(session,
                        inputId = "columns",
                        label = "Select Columns",
                        choices = column.name.vector(inFile),
                        selected = column.name.vector(inFile)[1]
      )
    }
  })
  observeEvent(input$button, {                    # React to submit button
    text.dataframe <- CreateTextDataframe()
    text.dataframe <- CleanDataframe(text.dataframe)
    keywords.count <- length(unique(text.dataframe$keywords))  # Get number of input keywords
    ################################## plotting part of the code ############################################
    output$sentences<- renderDataTable( {                   # Sentences Analyzed in the Text
      text.dataframe.extract <- subset(text.dataframe, 
                                       select=c("keywords", "org.text", "clean.text"))
      colnames(text.dataframe.extract) <- c("Keywords", "Original Text", "Processed Text") 
      text.dataframe.extract
    },
    options = list(lengthMenu = c(10, 50, 100), pageLength = 10)
    )
    
    output$sent_polarity_plot_txt <- renderUI( {                      # Overall text sentiment with labels
      keywords.count <- length(unique(text.dataframe$keywords))
      sent.polarity.output.list <- lapply(1:keywords.count, function(i) {
        plotname <- paste("sent.polarity", i, sep = "")
        plotlyOutput(plotname)
      })
      do.call(tagList, sent.polarity.output.list)
    })
    for (i in 1:keywords.count) {
      local({
        my.i <- i
        plotname <- paste("sent.polarity", my.i, sep = "")
        text.dataframe <- subset(text.dataframe,
                                 keywords == unique(text.dataframe$keywords)[my.i])
        sentiment.dataframe <- ConvertDataframe(text.dataframe,
                                                rule = "sentiment")
        output[[plotname]] <- renderPlotly({
          plot_ly(sentiment.dataframe, 
                  x = ~ave_sentiment, 
                  y = ~element_id, 
                  type = "scatter", 
                  mode = "none",
                  text = ~paste("Sentiment: ", ave_sentiment,
                                "</br> Text: ", substr(clean.text, 1, 10), 
                                "...", substr(clean.text, 
                                              length(clean.text) - 10,
                                              length(clean.text))
                  )
          )%>%
            add_segments(x = ~ave_sentiment - 0.25,
                         xend = ~ave_sentiment + 0.25,
                         y = ~element_id,
                         yend = ~element_id,
                         color = ~sentiment.pol
            ) %>%
            layout(# title = unique(text.dataframe$keywords)[my.i],
                   xaxis = list(title = "Sentiment Score",
                                range = c(-1, 1)),
                   yaxis = list(title = "Sentence Number"),
                   showlegend = FALSE)
        })
        # output[[plotname]] <- renderPlot({
        #   plot.temp <- ggplot(sentiment.dataframe,
        #                       aes(element_id, ave_sentiment, fill = sentiment.pol)) +
        #     geom_bar(stat = "identity",
        #              position = position_dodge(),
        #              color = "grey",
        #              width = 0.25) +
        #     guides(fill = FALSE) +
        #     coord_flip() +
        #     scale_fill_hue (c = 100, l = 80) +
        #     scale_fill_manual(values = c("pink", "white", "green")) +
        #     labs(x = "Sentence Number",
        #          y = "Sentiment Score",
        #          panel.background = element_rect(fill = "white"))
        #   plot.temp + geom_text(aes(label = clean.text),
        #                         hjust = 0.02,
        #                         vjust = 0.5,
        #                         nudge_y = ifelse(sentiment.dataframe$ave_sentiment > 0,-0.3,0.1))
        # })
      })
    }
    output$sent_polarity_pie <- renderUI({
      keywords.count <- length(unique(text.dataframe$keywords))
      sent.polarity.pie.output.list <- lapply(1:keywords.count, function(i) {
        plotname <- paste("sent.polarity.pie", i, sep = "")
        plotlyOutput(plotname)
      })
      do.call(tagList, sent.polarity.pie.output.list)
    })
    for (i in 1:keywords.count) {
      local({
        my.i <- i
        plotname <- paste("sent.polarity.pie", my.i, sep = "")
        text.dataframe <- subset(text.dataframe,
                                 keywords == unique(text.dataframe$keywords)[my.i])
        sentiment.dataframe <- ConvertDataframe(text.dataframe,
                                                rule = "sentiment")
        output[[plotname]] <- renderPlotly({
          sentiment.dataframe %>%
            group_by(sentiment.pol) %>%
            summarize(count = n()) %>%
            plot_ly(labels = ~sentiment.pol,
                    values = ~count,
                    marker = list(colors = c('#d35e60', '#B2B2B2','#52b243'),
                                  line = list(color = '#FFFFFF', width = 1))
                    ) %>%
            add_pie(hole = 0.6) %>%
            layout(#title = unique(text.dataframe$keywords)[my.i],
                   showlegend = T,
                   xaxis = list(showgrid = FALSE, zeroline = FALSE, showticklabels = FALSE),
                   yaxis = list(showgrid = FALSE, zeroline = FALSE, showticklabels = FALSE)
                   )
        })
      })
    }
    output$overall_sent_plot <- renderUI( {                         # Overall text sentiment
      keywords.count <- length(unique(text.dataframe$keywords))
      overall.sent.output.list <- lapply(1:keywords.count, function(i) {
        plotname <- paste("overall.sent", i, sep = "")
        plotOutput(plotname)
      })
      do.call(tagList, overall.sent.output.list)
    })
    for (i in 1:keywords.count) {
      local({
        my.i <- i
        plotname <- paste("overall.sent", my.i, sep = "")
        text.dataframe.subset <- subset(text.dataframe,
                                 keywords == unique(text.dataframe$keywords)[my.i])
        sentiment.by.object <- sentiment_by(
          text.dataframe.subset$clean.text
        )
        output[[plotname]] <- renderPlot({
          plot(sentiment.by.object) +
            ylim(-100, 100) + 
            geom_hline(yintercept = 0) +
            labs(x = "Emotions ", y = "Sentiment Score") +
            ggtitle(unique(text.dataframe$keywords)[my.i])
        })
      })
    }
    output$wordcloud_plot <- renderUI( {                                # Wordcloud
      keywords.count <- length(unique(text.dataframe$keywords))
      wordcloud.output.list <- lapply(1:keywords.count, function(i) {
        plotname <- paste("wordcloud", i, sep = "")
        plotOutput(plotname)
      })
      do.call(tagList, wordcloud.output.list)
    })
    for (i in 1:keywords.count) {
      local({
        my.i <- i
        plotname <- paste("wordcloud", my.i, sep = "")
        pal <- brewer.pal(8, "Dark2")
        freq.df <- create_wordcloud(
          subset(text.dataframe,
                 text.dataframe$keywords == unique(text.dataframe$keywords)[my.i])$clean.text,
          input$ngram[1],
          input$ngram[2]
        )
        output[[plotname]] <- renderPlot({
          layout(matrix(c(1, 2), nrow = 2), heights = c(1, 4))
          par(mar=rep(0, 4))
          plot.new()
          # text(x = 0.5, y = 0.1, unique(text.dataframe$keywords)[my.i])
          wordcloud(freq.df$word,
                    freq.df$freq,
                    #scale=c(8,.2),
                    min.freq=5,
                    max.words = Inf,
                    random.order = F,
                    rot.per=.15,
                    colors = pal,
                    main = "Title"
          )
        })
      })
    }
    ######## DISABLE FOR NOW ######
    # Plot the positive word cloud
    # output$wordcloud_pos_plot <- renderPlot(
    #   width = 1000, height = 1000, {
    #   layout(matrix(1:3, ncol = 3))
    #   for (i in unique(text.positive.dataframe$keywords)) {
    #     pal = brewer.pal(8, "Dark2")   # Set color style
    #     # text(x = 0.5, y = 0.5, i)  # Set name of title
    #     freq.df <- create_wordcloud(
    #       subset(text.positive.dataframe, 
    #              text.positive.dataframe$keywords == i)$clean.text
    #     )
    #     wordcloud(freq.df$word, 
    #               freq.df$freq, 
    #               max.words = 100, 
    #               random.order = F, 
    #               colors = pal
    #               # main = "Title"
    #     )
    #   }
    # })
    # Plot the negative word cloud
    # output$wordcloud_pos_plot <- renderPlot(
    #   width = 1000, height = 1000, {
    #   layout(matrix(1:3, ncol = 3))
    #   for (i in unique(text.negative.dataframe$keywords)) {
    #     pal = brewer.pal(8, "Dark2")   # Set color style
    #     # text(x = 0.5, y = 0.5, i)  # Set name of title
    #     freq.df <- create_wordcloud(
    #       subset(text.negative.dataframe, 
    #              text.negative.dataframe$keywords == i)$clean.text
    #     )
    #     wordcloud(freq.df$word, 
    #               freq.df$freq, 
    #               max.words = 100, 
    #               random.order = F, 
    #               colors = pal
    #               # main = "Title"
    #     )
    #   }
    # })    
    ###############
    output$freq_plot <- renderUI( {                                    # Word frequencies All
      keywords.count <- length(unique(text.dataframe$keywords))
      freq.output.list <- lapply(1:keywords.count, function(i) {
        plotname <- paste("freq", i, sep = "")
        plotlyOutput(plotname)
      })
      do.call(tagList, freq.output.list)
    })
    for (i in 1:keywords.count) {
      local({
        my.i <- i
        plotname <- paste("freq", my.i, sep = "")
        freq.df <- create_wordcloud(
          subset(text.dataframe,
                 text.dataframe$keywords == unique(text.dataframe$keywords)[my.i])$clean.text,
          input$ngram[1],
          input$ngram[2]
        )
        output[[plotname]] <- renderPlotly({
          plot_ly(head(freq.df, input$count.frequency.words),
                  x = ~freq,
                  y = ~reorder(word, freq),
                  type = "bar",
                  orientation = "h",
                  marker = list(color = 'rgba(50, 131, 168, 0.6)',
                                line = list(color = 'rgba(50, 131, 168, 1.0)', width = 1))) %>%
            layout(# title = unique(text.dataframe$keywords)[my.i],
                   margin = list(l = 80),
                   xaxis = list(title = "Frequency"),
                   yaxis = list(title = ""))
        })
      })
    }
    output$freq_pos_plot <- renderUI( {                                    # Word frequencies Positive
      keywords.count <- length(unique(text.dataframe$keywords))
      freq.output.list <- lapply(1:keywords.count, function(i) {
        plotname <- paste("freq.positive", i, sep = "")
        plotlyOutput(plotname)
      })
      do.call(tagList, freq.output.list)
    })
    for (i in 1:keywords.count) {
      local({
        my.i <- i
        plotname <- paste("freq.positive", my.i, sep = "")
        text.dataframe <- ConvertDataframe(text.dataframe, rule = "positive")
        freq.df <- create_wordcloud(
          subset(text.dataframe,
                 text.dataframe$keywords == unique(text.dataframe$keywords)[my.i])$clean.text,
          input$ngram[1],
          input$ngram[2]
        )
        output[[plotname]] <- renderPlotly({
          plot_ly(head(freq.df, input$count.frequency.words),
                  x = ~freq,
                  y = ~reorder(word, freq),
                  type = "bar",
                  orientation = "h",
                  marker = list(color = 'rgba(50, 131, 168, 0.6)',
                                line = list(color = 'rgba(50, 131, 168, 1.0)', width = 1))) %>%
            layout(# title = unique(text.dataframe$keywords)[my.i],
                   margin = list(l = 80),
                   xaxis = list(title = "Frequency"),
                   yaxis = list(title = ""))
        })
      })
    }
    output$freq_neg_plot <- renderUI( {                                    # Word frequencies Negative
      keywords.count <- length(unique(text.dataframe$keywords))
      freq.output.list <- lapply(1:keywords.count, function(i) {
        plotname <- paste("freq.negative", i, sep = "")
        plotlyOutput(plotname)
      })
      do.call(tagList, freq.output.list)
    })
    for (i in 1:keywords.count) {
      local({
        my.i <- i
        plotname <- paste("freq.negative", my.i, sep = "")
        text.dataframe <- ConvertDataframe(text.dataframe, rule = "negative")
        freq.df <- create_wordcloud(
          subset(text.dataframe,
                 text.dataframe$keywords == unique(text.dataframe$keywords)[my.i])$clean.text,
          input$ngram[1],
          input$ngram[2]
        )
        output[[plotname]] <- renderPlotly({
          plot_ly(head(freq.df, input$count.frequency.words),
                  x = ~freq,
                  y = ~reorder(word, freq),
                  type = "bar",
                  orientation = "h",
                  marker = list(color = 'rgba(50, 131, 168, 0.6)',
                                line = list(color = 'rgba(50, 131, 168, 1.0)', width = 1))) %>%
            layout(# title = unique(text.dataframe$keywords)[my.i],
                   margin = list(l = 80),
                   xaxis = list(title = "Frequency"),
                   yaxis = list(title = ""))
        })
      })
    }
    # output$topic_plot <- renderUI({                                        # Key topics identified in data
    #   keywords.count <- length(unique(text.dataframe$keywords))
    #   topic.output.list <- lapply(1:keywords.count, function(i) {
    #     plotname <- paste("topic", i, sep = "")
    #     tableOutput(plotname)
    #   })
    #   do.call(tagList, topic.output.list)
    # })
    # for (i in 1:keywords.count) {
    #   local({
    #     my.i <- i
    #     plotname <- paste("topic", my.i, sep = "")
    #     top.terms.df <- topic_model(
    #       subset(text.dataframe,
    #              text.dataframe$keywords == unique(text.dataframe$keywords)[my.i])$clean.text
    #     )
    #     output[[plotname]] <- renderTable({
    #       top.terms.df
    #     })
    #   })
    # }
    output$topic_plot <- renderDataTable({
      top.terms.df <- topic_model(
        subset(text.dataframe,
               text.dataframe$keywords == unique(text.dataframe$keywords)[1])$clean.text,
        input$k
      )
      top.terms.df$keywords <- rep(unique(text.dataframe$keywords)[1],
                                   nrow(top.terms.df))
      keywords.count <- length(unique(text.dataframe$keywords))
      if (keywords.count > 1) {
        for (i in 2:keywords.count) {
          top.terms.df.subset <- topic_model(
            subset(text.dataframe,
                   text.dataframe$keywords == unique(text.dataframe$keywords)[i])$clean.text,
            input$k
          )
          top.terms.df.subset$keywords <- rep(unique(text.dataframe$keywords)[i],
                                              nrow(top.terms.df.subset))
          top.terms.df <- bind_rows(top.terms.df, top.terms.df.subset)
        }
      }
      top.terms.df %>% select(keywords, everything())
    },
    options = list(lengthMenu = c(10, 50, 100), pageLength = 10)
    )
    # output$html_txt <- renderUI({                                           # Plot the output HTML
    #   keywords.count <- length(unique(text.dataframe$keywords))
    #   html.output.list <- lapply(1:keywords.count, function(i) {
    #     plotname <- paste("html", i, sep = "")
    #     uiOutput(plotname)
    #   })
    #   do.call(tagList, html.output.list)
    # })
    # for (i in 1:keywords.count) {
    #   local({
    #     my.i <- i
    #     plotname <- paste("html", my.i, sep = "")
    #     text.dataframe.subset <- subset(text.dataframe,
    #                                     text.dataframe$keywords == unique(text.dataframe$keywords)[my.i])
    #     sentiment.by.object <- sentiment_by(
    #       text.dataframe.subset$clean.text
    #     )
    #     set.seed(2)
    #     output[[plotname]] <- highlight(sentiment.by.object,
    #                                     # text.dataframe.subset$org.text
    #                                     open = T)
    #   })
    # }
    output$button.exportcsv <- downloadHandler(                              # Excel Uploaded Data
      filename = function() {
        paste("Sentiment Analysis ",
              Sys.Date(),
              ".csv",
              sep = "")
      },
      content = function(file) {
        write.csv(data.frame(lapply(text.dataframe, as.character),
                             stringsAsFactors = FALSE
        ),
        file,
        row.names = FALSE
        )
      }
    )
    # output$button.exportreport <- downloadHandler(
    #   filename = function() {
    #     paste("Sentiment Analysis Report ",
    #           Sys.Date(),
    #           ".pdf",
    #           sep = "")
    #   },
    #   content = function(file) {
    #     src <- normalizePath('report.Rmd')
    #     owd <- setwd(tempdir())
    #     on.exit(setwd(owd))
    #     file.copy(src, "report.Rmd", overwrite = TRUE)
    #     library(rmarkdown)
    #     out <- rmarkdown::render("report.Rmd", 
    #                              pdf_document(),
    #                              output_file = file
    #                              # keywords.count = keywords.count,
    #                              # envir = new.env(parent = globalenv())
    #     )
    #     file.rename(out, file)
    #   }
    # )
    output$table_display <- renderDataTable({
      text.dataframe
    },
    options = list(lengthMenu = c(10, 50, 100), pageLength = 10)
    )
  })
})











