require File.dirname(__FILE__) + '/output'
require File.dirname(__FILE__) + '/puller'
#require File.dirname(__FILE__) + '/logger'

gem 'kronos', '>= 0.1.6'
require 'kronos'
require 'uri'

class SourcePuller < Puller

  def initialize
    @metadata_master=[]
    @base_uri       = 'https://wiki.state.ma.us/confluence/display/data/Data+Catalog'
    @uri            = 'http://wiki.state.ma.us'
    @details_folder = Output.dir  '/../cache/raw/source/detail'
    @index_data     = Output.file '/../cache/raw/source/index.yml'
    @index_html     = Output.file '/../cache/raw/source/index.html'
   # @pull_log       = Output.file '/../cache/raw/source/pull_log.yml'
    super
  end


  def get_subsets
    doc=U.parse_html_from_file_or_uri(@base_uri,@index_html,:force_fetch=>false)

    nodes=doc.xpath("//div[@class='wiki-content']//ul//li")
    links_and_tags=[]
    nodes.each do |node|
      a_tag=node.css("a").first
      link=URI.unescape(a_tag["href"])
      tag=a_tag["title"]
      tag.gsub!(" Data","")
      links_and_tags<<["https://wiki.state.ma.us"+link,tag]
    end
    {:links_and_tags=>links_and_tags}
  end

  def merge_subset_to_master(subset)
	  @metadata_master<<subset
  end

  #Iterates through each subset parsing it for metadata and combining that with the master set.
  def get_metadata
    sets=get_subsets
    sets[:links_and_tags].each do |link,tag|
      file=Output.file '/../cache/raw/source/'+tag+'.html'
      doc=U.parse_html_from_file_or_uri(link,file,:force_fetch=>false)

      subset_metadata=get_metadata_from_subset(doc,tag)
      merge_subset_to_master(subset_metadata)
    end
      debugger
    @metadata_master
  end

  def get_metadata_from_subset(doc,set_tag)
	  table_rows=doc.xpath("//table[@class='confluenceTable']//tr")

	  metadata=[]
	  table_rows.delete(table_rows[0])
	  table_rows.each do |row|
		  formats={}
		  cells=row.css("td")
      format_cell=cells.last

      format_links=format_cell.css("a")
      next if format_links.empty?

      format_links.each do |node|
        add_formats(formats,node)
      end


		metadata<<{
      :tags=>set_tag,
      :source_organization=>{:name=>U.single_line_clean(cells[0].inner_text),
                             :href=>get_href_from_node(cells[0])},
      :metadata=>{:title=>U.single_line_clean(cells[1].inner_text),
                  :href=>get_href_from_node(cells[1])},
      :contact=>get_contact_from_node(cells[3]),
			:title=>cells[1].inner_text,
			:description=>U.multi_line_clean(cells[2].inner_text),
			:formats=>formats
		}
	  end

	metadata
  end

  def get_contact_from_node(node)
    mailto=get_href_from_node(node)
    unless mailto.nil?
      email=mailto.gsub("mailto:","")
      return {:email=>email, :name=>node.inner_text}
    else
      return node.inner_text
    end
  end

  def get_href_from_node(node)
    a_tag=node.css("a").first
    if a_tag
      return URI.unescape(a_tag["href"])
    else
      return nil
    end
  end

  def add_formats(formats,node)
		  link=@uri+URI.unescape(node["href"])
		  formats[node.inner_text]={:href=>link}
  end

	def parse_metadata(metadata)
		m={
			:title=>metadata[:title],
			:description=>metadata[:description],
			:source_type=>"dataset",
			:catalog_name=>"utah.gov",
			:catalog_url=>@base_uri,
			:frequency=>"unknown"
		  }
		  downloads=[]
		  metadata[:formats][:downloads].each do |key,value|
			downloads<<{ :url=>value[:href],:format=>key}
		  end

		  source=metadata[:formats][:source]
		  m[:organization]={:home_url=>source[:source_url] ,
			  	    :name=>source[:source_org] }

		  m[:downloads]=downloads
		  m
	end

end
