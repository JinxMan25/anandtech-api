class ArticlesController < ApplicationController
  before_filter :get_articles, :only => :articles 
  require 'open-uri'
  def articles
    @articles = {:articles => @all_articles, :featured_articles => @featured_articles }
    render :json => @articles
  end

  def search_articles
    search_query = params[:search_query]
  end

  def filtered
    _filter = params[:filter].to_s
    if params[:page]
      page = params[:page]
    else
      page = 1
    end
    
    url = "http://anandtech.com/tag/#{_filter}/#{page}"

    doc = Nokogiri::HTML(open(url))
    @filtered_articles = Rails.cache.fetch("articles/#{_filter}", :expires_in => 5.minute) do
      scrape_articles(doc, true)
    end

    @articles = { :articles => @filtered_articles }

    render :json => @articles
  end

  def single_cpu_benchmark
    value = params[:value]

    url = "http://anandtech.com/bench/product/#{value}"

    doc = Nokogiri::HTML(open(url))

    @benchmark = []

    benchmark = doc.css(".rating_list")
    benchmark.each do |bar|
      description = bar.css("span").text

      rating = bar.css("strong").text
      benchmark = { :description => description, :rating => rating }
      @benchmark << benchmark
    end
    render :json => @benchmark
  end

  def bench_comparison
    first_product = params[:first].to_s
    second_product = params[:second].to_s

    url = "http://anandtech.com/bench/product/#{first_product}?vs=#{second_product}"

    doc = Nokogiri::HTML(open(url))

    @bench_comparison = Rails.cache.fetch("bench/#{first_product}/#{second_product}", :expires_in => 3.days) do
      get_bench(doc)
    end

    render :json => @bench_comparison

  end

  def search_results
    search = params[:querystring].to_s
    search.gsub!(/\s/, "+")

    url = "http://anandtech.com/SearchResults?q=#{search}"

    doc = Nokogiri::HTML(open(url))
    
    render :json => {:string => search }

  end

  def next_page
    page = params[:page].to_i

    url = "http://anandtech.com/Page/#{page}"
    @all_articles = Rails.cache.fetch("articles/#{page}", :expires_in => 5.minute) do
      scrape_articles(doc, false)
    end
  end

  def get_article_content
    anchor = params[:link].to_s
    anchor.gsub!(/\*\*/, "/")
    link = "http://anandtech.com/#{anchor}"

    doc = Nokogiri::HTML(open(link))
    article_title = doc.css(".blog_top_left h2").text
    review = doc.at(".review")
    article_content = []
    select_options = []
    review.children.each do |item|
      item.children.each do |divelement|
        if divelement.name == "img" && !!(divelement.attr("src").to_s =~ /images.anandtech/)
         img_url = item.css("img").attr("src").to_s
         article_content.push(img_url)
        elsif divelement.name == ("select")
          divelement.css("option").each do |option|
            link = option.attr("value").to_s
            link_title = option.text
            tempOption = { :title => link_title, :url => link }
            select_options << tempOption
          end
        elsif divelement.name == ("p")
          if !divelement.css("img").empty?
            img_url = divelement.css("img").attr("src").to_s
            article_content.push(img_url)
          else
          paragraph = divelement.text
          article_content.push(paragraph)
          end
        end
      end
    end
    @article = {:article => article_content, :title => article_title, :select_options => select_options }
    render :json => @article
  end

  private

  def get_bench(doc)
    rating_list = doc.css(".rating_list")
    @winner = []
    @loser = []

    product_1 = doc.css(".compare1").text.gsub(/\s\s/, "")
    product_2 = doc.css(".compare2").text.gsub(/\s\s/, "")
    
    rating_list.each do |rating|
      description = rating.css(".rating_bench strong").text

      win_score = rating.css(".win strong").text
      winner_rating = { :description => description, :rating => win_score }
      @winner << winner_rating

      lose_score = rating.css(".lose strong").text
      loser_rating = { :description => description, :rating => lose_score }
      @loser << loser_rating
    end
    @comparison = { :winner => @winner, :loser => @loser, :product_1 => product_1, :product_2 => product_2 }
  end

  def get_articles
    require 'open-uri'
    
    @featured_articles = []

    doc = Nokogiri::HTML(open("http://anandtech.com"))

    @all_articles = #Rails.cache.fetch("anandtech/articles", :expires_in => 5.minute) do 
      scrape_articles(doc, false)
    #end
    @all_articles.each do |article|
      if article[:featured]
        @featured_articles << article 
      end
    end
    @all_articles.select!{ |k| k if !k[:featured] }
  end


  def scrape_articles(doc, isFiltered)
    
    @data = []

    if isFiltered
      document = doc.css(".cont_box1")
    else
      document = doc.css(".l_")
    end

    document.each do |article_container|
      article_title = article_container.css("h2").text

      source = article_container.css("a").attr("href").text
      source.gsub!(/\//, "**") 
      source.gsub!(/^\*\*/, "")
      source_4dcode = /\d\d\d\d/.match("#{source}").to_s
    
      image_link = article_container.css("img").first.attr("src")

      article_description = article_container.css(".cont_box1_txt p").text

      author = article_container.css(".cont_box1_txt .b").text

      comment_count = article_container.css(".cont_box1_txt strong").text

      posted_on = article_container.css(".cont_box1_txt span").text

      posted = /[0-9]\s\w+\s\w+/.match("#{posted_on}").to_s  

      if posted.empty?
        posted = /\d+\W\d+\W[0-9]+/.match("#{posted_on}").to_s
      else
      end

      temp_cell = { :title => article_title, :link => source, :image_url => image_link, :author => author, :description => article_description, :comments => comment_count, :posted => posted }
    @data << temp_cell
    end
    #featured stories
    doc.css(".hide_resp2 h2 a , .featured_info h2 a").each do |featured_title|
      source = featured_title.attr("href")
      tempCell = { :title => featured_title.text, :featured => "true", :link => source }
      @data << tempCell
    end
    @data
  end
end
