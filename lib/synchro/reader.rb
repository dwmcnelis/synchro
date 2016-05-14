module Synchro

  class Reader

    require 'nokogiri'
    require 'open-uri'
    require 'open_uri_redirections'
    require 'redis'
    require 'zip'
    require 'colorize'
    require 'byebug'


    READ_TIMEOUT = 120
    READ_RETRIES = 3

    attr_reader :url, :packages


    def initialize(url, options={})
      @redis_url = options[:redis_url] || ENV['REDIS_URL'] || nil
      @url = url
      @packages = []
    end


    def redis
      @redis ||= begin
        @redis_url ? Redis.new(url: redis_url) : Redis.new
      end
    end


    # Download feed directory
    #
    def dir
      resource = open(@url, :allow_redirections => :all, :read_timeout => READ_TIMEOUT)
      base_uri = resource.base_uri.to_s

      doc = Nokogiri::HTML(resource)
      rows = doc.xpath('//table/tr')

      @packages = rows.inject([]) do |result, row|
        cells = row.xpath('td')
        if cells.count == 4
          name = cells[0].text
          if name =~ /([0-9A-Za-z]*)\.(zip|ZIP)/
            key = name.split('.').first
            link = URI.join(base_uri,name).to_s
            date = DateTime.parse(cells[1].text)
            size = cells[2].text.strip
            result << {key: key, link: link, name: name, date: date, size: size}
          end
        end
        result
      end
    end


    # Download a feed package (zip file) and load into Redis
    #
    # @param [Hash] options
    # @option [String] force_download whether cached or not
    #
    def download(package, options=())
      force_download = options[:force_download]
      package_key = "package:#{package[:key]}"
      puts "download package #{package_key} (#{package[:size]})".colorize(:light_green)

      tries ||= READ_RETRIES
      begin

        # Download package using explict tempfile for content reguardless of size
        zipfile = Tempfile.new(['news','.zip'])
        open(package[:link], :allow_redirections => :all, :read_timeout => READ_TIMEOUT) do |io|
          zipfile.write(io.read)
        end
        zipfile.close

        # Unzip articles
        Zip::File.open(zipfile.path) do |zip_file|
          zip_file.each do |entry|
            if entry.file?
              entry_name = entry.name.dup
              key = entry_name.split('.').first
              article_key = "article:#{package[:key]}:#{key}"

              redis.del(article_key) if force_download

              unless redis.exists(article_key)
                puts "new article #{article_key}".colorize(:light_green)
                content = entry.get_input_stream.read
                redis.set(article_key, content)
              else
                puts "cached article #{article_key}".colorize(:light_green)
              end
            end
          end
        end

        redis.set(package_key, package[:date])

      rescue Net::ReadTimeout => e
        unless (tries -= 1).zero?
          puts "retrying package #{package[:key]}, after read timeout".colorize(:light_yellow)
          retry
        end
      rescue StandardError => e
        puts "skipping package #{package[:key]}, #{e.message}!".colorize(:red) # TODO: log
      end

    end

    # Sync all packages from feed directory, downloading package when necessary
    #
    # @param [Hash] options
    # @option [String] force_download whether cached or not
    #
    def sync(options={})
      force_download = options[:force_download]
      unless @packages.empty?
        @packages.each do |package|
          package_key = "package:#{package[:key]}"
          redis.del(package_key) if force_download
          package_date = redis.get(package_key) || DateTime.parse('2000-01-01').to_s

          if package[:date] > DateTime.parse(package_date)
            puts "new package #{package_key}".colorize(:light_green)
            download(package, options)
          else
            puts "cached package #{package_key}".colorize(:light_yellow)
          end
        end
      end
    end

    # Convert to hash. Super useful when using awesome_print or ap alias in
    # console or debugger:
    #
    # 2.1.6 :074 > ap reader
    # (byebug) ap reader
    #
    def to_hash
      hash = {}
      %w(
        url packages
      ).inject(hash) do |result, method|
        result[method.to_sym] = self.send(method.to_sym)
        result
      end
    end

    class << self

      # Go process a url to retrieve feed directory
      # and download articles
      #
      # @param url
      # @param [Hash] options
      # @option [String] redis_url
      # @option [String] force_download whether cached or not
      #
      def go(url, options={})
        reader = self.new(url, options)
        reader.dir
        reader.sync(options)

        reader
      end


      # List packages in Redis cache
      #
      # @param [Hash] options
      # @option [String] redis_url
      #
      def packages(options={})
        reader = self.new(nil, options)
        reader.redis.scan_each(match: 'package:*') do |key|
          key = key.split(':').last
          puts "#{key}"
        end
      end


      # List articles in Redis cache
      #
      # @param [String] package id
      # @param [Hash] options
      # @option [String] redis_url
      #
      def articles(package, options={})
        reader = self.new(nil, options)
        if package =~ /([0-9A-Za-z]*)/
          package_key = "package:#{package}"
          if reader.redis.get(package_key)
            reader.redis.scan_each(match: "article:#{package}:*") do |key|
              key = key.split(':').last(2).join(':')
              puts "#{key}"
            end
          else
            puts "package not found".colorize(:red)
          end
        else
          puts "invalid package".colorize(:red)
        end
      end


      # Retrieve an article from Redis cache
      #
      # @param [String] article id
      # @param [Hash] options
      # @option [String] redis_url
      #
      def article(article, options={})
        reader = self.new(nil, options)
        if article =~ /([0-9A-Za-z]*):([0-9A-Za-z]*)/
          article_key = "article:#{article}"
          content = reader.redis.get(article_key)
          unless content.nil?
            puts content
          else
            puts "article not found".colorize(:red)
          end
        else
          puts "invalid article".colorize(:red)
        end
      end


      # Flush Redis package:* and article:*:* keys
      # @param [Hash] options
      # @option [String] redis_url
      #
      def flush(options={})
        reader = self.new(nil, options)
        deleted = 0
        reader.redis.scan_each(match: "package:*") do |key|
          reader.redis.del(key)
          deleted += 1
        end
        reader.redis.scan_each(match: "article:*:*") do |key|
          reader.redis.del(key)
          deleted += 1
        end
        deleted
      end

    end

  end # Reader

end # Synchro