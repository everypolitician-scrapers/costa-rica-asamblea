#!/bin/env ruby
# encoding: utf-8

require 'nokogiri'
require 'pry'
require 'scraperwiki'

require 'open-uri/cached'
OpenURI::Cache.cache_path = '.cache'

class String
  def tidy
    self.gsub(/[[:space:]]+/, ' ').strip
  end
end

def noko_for(url)
  Nokogiri::HTML(open(url).read)
end

def scrape_list(url)
  noko = noko_for(url)
  noko.css('table[summary="Diputadas y diputados"] img[src*="Diputados"]/@src').each do |img|
    f_info = img.xpath('preceding::a[contains(@href,"Lists/Fracciones")]').last.text
    found = f_info.match(/Fracción Partido (.*) \((.*)\)/) or raise "Unknown faction: #{f_info}"
    faction, faction_id = found.captures

    tds = img.xpath('ancestor::tr[1]/td')
    # Included URL is a redirect, so resolve it
    source_url = tds[2].css('a/@href').text
    source = open(source_url) { |f| f.base_uri.to_s }

    family_name = tds[2].text.tidy
    given_name = tds[3].text.tidy

    data = { 
      id: source[/Cedula_Diputado=(\d+)/, 1],
      name: "%s %s" % [given_name, family_name],
      sort_name: "%s, %s" % [family_name, given_name],
      given_name: given_name,
      family_name: family_name,
      faction_id: faction_id,
      faction: faction,
      image: img.text,
      term: 2014,
      source: source,
    }
    data[:image] = URI.join(url, data[:image]).to_s unless data[:image].to_s.empty?
    ScraperWiki.save_sqlite([:id, :term], data)
  end
end

scrape_list('http://www.asamblea.go.cr/Diputadas_Diputados/Lists/Diputados/Diputadas%20y%20diputados%20por%20Fraccin.aspx')
