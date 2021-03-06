require File.dirname(__FILE__) + '/output'
require File.dirname(__FILE__) + '/puller'

gem 'kronos', '>= 0.1.6'
require 'kronos'
require 'uri'

class SourcePuller < Puller

  def initialize
    @metadata_master = []
    @base_uri        = 'https://wiki.state.ma.us/confluence/display/data/Data+Catalog'
    @uri             = 'https://wiki.state.ma.us'
    @details_folder  = Output.dir  '/../cache/raw/source/detail'
    @index_data      = Output.file '/../cache/raw/source/index.yml'
    @index_html      = Output.file '/../cache/raw/source/index.html'
    super
  end

  def merge_subset_to_master(subset)
    subset.each { | data | @metadata_master << data }
  end

  #Iterates through each subset parsing it for metadata and combining that with the master set.
  def get_metadata
    sets = get_subsets
    sets[:links_and_tags].each do | link, tag |
      file = Output.file '/../cache/raw/source/' + tag + '.html'
      doc = U.parse_html_from_file_or_uri(link, file, :force_fetch => true)

      subset_metadata = get_metadata_from_subset(doc, tag)
      merge_subset_to_master(subset_metadata)
    end
    @metadata_master
  end

	def parse_metadata(metadata)
    if metadata[:formats]
		  downloads = []
		  metadata.delete(:formats).each do |key,value|
        downloads << { :url => value[:href], :format => key }
		  end
    end

    metadata[:catalog_name] = "Massachusetts State Data Catalog"
    metadata[:catalog_url]  = @base_uri
    metadata[:downloads]    = downloads
    metadata
	end

  protected

  def get_metadata_from_subset(doc, set_tag)
	  table_rows = doc.xpath("//table[@class='confluenceTable']//tr")

	  metadata = []
	  table_rows.delete(table_rows[0])
	  table_rows.each do | row |

		  cells = row.css("td")
      next if U.single_line_clean(cells[0].inner_text).empty?
      m = {
          :organization => { :name => U.single_line_clean(cells[0].inner_text),
                             :url  => get_href_from_node(cells[0])},
          :title        => U.single_line_clean(cells[1].inner_text),
          :url          => get_href_from_node(cells[1]),
          :description  => U.multi_line_clean(cells[2].inner_text),
      }

      add_to_custom(m, "tags", "data tags", "string", set_tag)
		  formats = {}
      format_cell = cells.last
      format_links = format_cell.css("a")

      #Distinguish between apis and datasets
      #Api's have no dataset source links downloads.
      #Datasets do
      if format_links.empty?
        m[:source_type] = "api"
      else
        format_links.each do | node |
          add_formats(formats, node)
        end
        m[:formats] = formats
        m[:source_type] = "dataset"
      end


    #If it has the modified date add it to the metadata, otherwise don't
    modified = get_last_modified(cells[4])
    add_to_custom(m, "modified", "last modified", "string", modified) if modified

    #Add contact if one exists, otherwise don't
    contact = get_contact_from_node(cells[3])
    add_to_custom(m, "contact", "The 'owner' for the current data",
                  "string", contact) if modified

    metadata << m
	  end
	metadata
  end

  private

  def add_to_custom(metadata, label, description, type, value)
    if metadata[:custom].nil?
      metadata[:custom] = {}
    end
    num = metadata[:custom].size.to_s
    metadata[:custom][num] = { :label => label,
                               :description => description,
                               :type  => type, :value => value}
  end

  def get_subsets
    doc = U.parse_html_from_file_or_uri(@base_uri, @index_html, :force_fetch => true)

    nodes = doc.xpath("//div[@class='wiki-content']//ul//li")
    links_and_tags = []
    nodes.each do | node |
      a_tag = node.css("a").first
      link = URI.unescape(a_tag["href"])
      tag = a_tag["title"]
      tag.gsub!(" Data", "")
      links_and_tags << [@uri + link, tag]
    end
    { :links_and_tags => links_and_tags }
  end

  def get_last_modified(node)
    inner = U.single_line_clean(node.inner_text.strip)
    inner == "N/A" ? nil : inner
  end


  def get_contact_from_node(node)
    mailto = get_href_from_node(node)
    unless mailto.nil?
      email = mailto.gsub("mailto:", "")
      return { :email => email, :name => node.inner_text }
    else
      inner = U.single_line_clean(node.inner_text)
      inner.empty? or inner == "N/A" ? nil : inner
    end
  end

  def get_href_from_node(node)
    a_tag = node.css("a").first
    if a_tag
      return URI.unescape(a_tag["href"])
    else
      return nil
    end
  end

  def add_formats(formats, node)
		  link = @uri + URI.unescape(node["href"])
		  formats[node.inner_text] = { :href => link }
  end

end
