require File.dirname(__FILE__) + '/output'
require File.dirname(__FILE__) + '/puller'

require 'uri'

class OrganizationPuller < Puller

  def initialize
    @metadata_master = []
    @base_uri        = 'https://wiki.state.ma.us/confluence/display/data/Data+Catalog'
    @uri             = 'https://wiki.state.ma.us'
    @details_folder  = Output.dir  '/../cache/raw/organization/detail'
    @index_data      = Output.file '/../cache/raw/organization/index.yml'
    @index_html      = Output.file '/../cache/raw/organization/index.html'
    super
  end

  def merge_subset_to_master(subset)
    subset.each { | data | @metadata_master << data } 
  end

  #Iterates through each subset parsing it for metadata and combining that with the master set.
  def get_metadata
    sets = get_subsets
    sets[:links_and_tags].each do | link, tag |
      file = Output.file '/../cache/raw/organization/' + tag + '.html'
      doc = U.parse_html_from_file_or_uri(link, file, :force_fetch => true)

      subset_metadata = get_metadata_from_subset(doc)
      merge_subset_to_master(subset_metadata)
    end
    @metadata_master
  end

# Returns as many fields as possible:
  #
  #   property :name
  #   property :names
  #   property :acronym
  #   property :org_type
  #   property :description
  #   property :slug
  #   property :url
  #   property :interest
  #   property :level
  #   property :source_count
  #   property :custom
  #
	def parse_metadata(metadata)
    metadata[:catalog_name] = "Massachusetts State Data Catalog"
    metadata[:catalog_url] = @base_uri
    metadata[:org_type] = "governmental"
    metadata[:organization] = { :name => "Massachusetts" }
    metadata
	end

  protected

  def get_metadata_from_subset(doc)
	  table_rows = doc.xpath("//table[@class='confluenceTable']//tr")

	  metadata = []
	  table_rows.delete(table_rows[0])
	  table_rows.each do |row|

		  cells = row.css("td")
      name = U.single_line_clean(cells[0].inner_text)
      url = get_href_from_node(cells[0])


      if name.empty?
        next if url.nil?
        name = a_tag(cells[0]).inner_text
      end
      m = {
        :name => name,
        :url  => url,
      }

      already_exists = metadata.find { |data| data[:url]==m[:url]}

      metadata << m unless already_exists
	  end
    metadata
  end

  private

  def get_subsets
    doc = U.parse_html_from_file_or_uri(@base_uri, @index_html, :force_fetch => false)

    nodes = doc.xpath("//div[@class='wiki-content']//ul//li")
    links_and_tags = []
    nodes.each do | node |
      a = a_tag(node)
      link = URI.unescape(a["href"])
      tag = a["title"]
      tag.gsub!(" Data", "")
      links_and_tags << [@uri + link, tag]
    end
    { :links_and_tags => links_and_tags }
  end


  def get_href_from_node(node)
    a = a_tag(node)
    a ? URI.unescape(a["href"]) : nil
  end

  def a_tag(node)
    node.css("a").first
  end
  
end
