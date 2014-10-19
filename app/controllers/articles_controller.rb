class ArticlesController < ApplicationController
  before_filter :get_articles, :only => :articles 
  require 'open-uri'
  def articles
    @articles = {:articles => @all_articles }
    render :json => @articles
  end

  private

  def get_articles
    require 'open-uri'

    doc = Nokogiri::HTML(open("http://anandtech.com"))

    @all_articles = Rails.cache.fetch("anandtech/articles/v2") do
      scrape_articles(doc)
    end
  end

  def scrape_articles(doc)
    
    @data = []

    doc.css(".l_").each do |article_container|
      article_title = article_container.css("h2").text
    
    temp_cell = { :title => article_title }
    @data << temp_cell
    end
    doc.css(".hide_resp2").each do |featured_container|
      featured_tltle = featured_container.css("h2").text
      tempCell = { :title => featured_tltle, :featured => "true" }
      @data << tempCell
    end
    @data
  end
end
