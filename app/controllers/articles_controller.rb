class ArticlesController < ApplicationController
  require 'open-uri'
  def articles

  end

  private

  def get_articles
    require 'open-uri'

    doc = Nokogiri::HTML(open("http://anandtech.com"))

    @articles = Rails.cache.fetch("anandtech/articles/v1") do
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
    @data
  end
end
