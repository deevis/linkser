require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'image_spec'
require 'opengraph'

module Linkser
  module Objects
    class HTML < Linkser::Object
      attr_reader :body, :nokogiri
      attr_reader :title, :description, :images, :ogp
      def initialize url, head, options={}
        super url, head, options
      end

      def title
        return @title unless @title.nil?
        if ogp and ogp.title
           @title = ogp.title
        else
          nokogiri.css('title').each do |title|
            @title = title.text
          end
        end          
        @title
      end

      def body
        return @body unless @body.nil?
        @body = open(url)
      end

      def description
        return @description unless @description.nil?
        if ogp and ogp.description
           @description = ogp.description
        else
          nokogiri.css('meta').each do |meta|
            if meta.get_attribute("name").eql? "description"
              @description = meta.get_attribute("content")
            end
          end
        end
        @description
      end

      def images
        return @images unless @images.nil?
        @images = Array.new
        if ogp and ogp.image
          begin
            img_spec = ImageSpec.new(ogp.image)
            if valid_img? img_spec.width.to_f, img_spec.height.to_f
              @images << {:img => ogp.image, :width => img_spec.width, :height => img_spec.height}
            end
          rescue
          end
        end        
        nokogiri.css('img').each do |img|
          img_src = img.get_attribute("src")
          img_src = complete_url img_src, url
          img_uri = URI.parse(img_src)
          img_ext = File.extname(img_uri.path)
          img_name = File.basename(img_uri.path,img_ext)
          if [".jpg", ".jpeg", ".png"].include? img_ext
            begin
              img_spec = ImageSpec.new(img_src)
              if valid_img? img_spec.width.to_f, img_spec.height.to_f
                @images << {:img => img_src, :width => img_spec.width, :height => img_spec.height}
              end
            rescue
            end
          end
        end
        @images
      end      

      def nokogiri
        return @nokogiri unless @nokogiri.nil?
        @nokogiri = Nokogiri::HTML(body)
      end

      def ogp
        return @ogp unless @ogp.nil?
        @ogp = OpenGraph::Object.new
        nokogiri.css('meta').each do |m|
          if m.attribute('property') && m.attribute('property').to_s.match(/^og:(.+)$/i)
            @ogp[$1.gsub('-','_')] = m.attribute('content').to_s
          end
        end
        @ogp = false if @ogp.keys.empty?
        @ogp = false unless @ogp.valid?  
        @ogp 
      end

      private

      def complete_url src, url
        uri = URI.parse(url)
        base_url = "http://" + uri.host + (uri.port!=80 ? ":" + uri.port.to_s : "")
        relative_url = "http://" + uri.host + (uri.port!=80 ? ":" + uri.port.to_s : "") + uri.path
        if src.index("http://")==0
          src
        elsif src.index("/")==0
          base_url + src
        else
          relative_url + src
        end
      end

      def valid_img? w, h
        if w > 199 or w > 199
          if ((w > 0 and h > 0 and ((w / h) < 3) and ((w / h) > 0.2)) or (w > 0 and h == 0 and w < 700) or (w == 0 and h > 0 and h < 700))
          return true
          end
        end
        false
      end
    end
  end
end