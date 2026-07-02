require 'time'

module RedminePluginCheck
  class TargetVersionCatalog
    TAGS_URL = 'https://svn.redmine.org/redmine/tags/'.freeze
    CACHE_VERSIONS_KEY = 'target_redmine_versions'.freeze
    CACHE_FETCHED_AT_KEY = 'target_redmine_versions_fetched_at'.freeze
    CACHE_TTL_SECONDS = 24 * 60 * 60

    def initialize(options = {})
      @fetcher = options[:fetcher]
      @settings_store = options[:settings_store]
      @now = options[:now] || lambda { Time.now }
    end

    def versions_for(current_version)
      current = gem_version(current_version)
      return [] unless current

      versions = cached_versions
      if versions.nil?
        versions = fetch_versions
        write_cache(versions)
      end

      versions.select { |version| gem_version(version) && gem_version(version) >= current }
    rescue StandardError
      []
    end

    def parse_versions(html)
      html.to_s.scan(/href=["']([^"']+)\/["']/).flatten.map do |href|
        href.to_s.sub(/\/$/, '').sub(/^.*\//, '')
      end.select do |version|
        version =~ /\A\d+\.\d+\.\d+\z/
      end.uniq.sort_by { |version| gem_version(version) }
    end

    private

    attr_reader :fetcher, :settings_store, :now

    def cached_versions
      settings = plugin_settings
      fetched_at = parse_time(settings[CACHE_FETCHED_AT_KEY])
      return nil unless fetched_at && now.call - fetched_at < CACHE_TTL_SECONDS

      versions = settings[CACHE_VERSIONS_KEY]
      versions = versions.split(',') if versions.is_a?(String)
      versions.respond_to?(:map) ? versions.map(&:to_s).reject(&:empty?) : nil
    end

    def fetch_versions
      parse_versions(fetch_html)
    end

    def fetch_html
      return fetcher.call(TAGS_URL) if fetcher

      require 'net/http'
      require 'uri'

      uri = URI.parse(TAGS_URL)
      response = Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https', :open_timeout => 5, :read_timeout => 10) do |http|
        http.get(uri.request_uri)
      end
      return response.body if response.is_a?(Net::HTTPSuccess)

      raise "HTTP #{response.code}"
    end

    def write_cache(versions)
      settings = plugin_settings
      settings[CACHE_VERSIONS_KEY] = versions.join(',')
      settings[CACHE_FETCHED_AT_KEY] = now.call.strftime('%Y-%m-%d %H:%M:%S %z')
      write_plugin_settings(settings)
    end

    def plugin_settings
      if settings_store
        source = settings_store.respond_to?(:call) ? settings_store.call : settings_store
      elsif defined?(Setting) && Setting.respond_to?(:plugin_redmine_plugin_check)
        source = Setting.plugin_redmine_plugin_check || {}
      else
        source = {}
      end

      settings = {}
      source.each { |key, value| settings[key.to_s] = value } if source.respond_to?(:each)
      settings
    end

    def write_plugin_settings(settings)
      if settings_store && settings_store.respond_to?(:[]=)
        settings_store.clear if settings_store.respond_to?(:clear)
        settings.each { |key, value| settings_store[key] = value }
      elsif defined?(Setting) && Setting.respond_to?(:plugin_redmine_plugin_check=)
        Setting.plugin_redmine_plugin_check = settings
      end
    end

    def parse_time(value)
      return value if value.is_a?(Time)
      return nil if value.to_s.strip.empty?

      Time.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def gem_version(value)
      text = value.to_s[/\d+(?:\.\d+){1,2}/]
      return nil unless text

      Gem::Version.new(text)
    rescue ArgumentError
      nil
    end
  end
end
