require 'json'
require 'net/http'
require 'openssl'
require 'timeout'
require 'uri'

module RedminePluginCheck
  class LatestVersionChecker
    Result = Struct.new(:version, :source, :error)

    USER_AGENT = 'RedminePluginCheck/1.0.0'.freeze
    TIMEOUT_SECONDS = 3

    def self.github_repository_from_url(url)
      text = url.to_s.strip
      return nil if text.empty?

      if text =~ /\Agit@github\.com:([^\/]+)\/(.+?)(?:\.git)?\z/i
        return [$1, cleanup_repo_name($2)]
      end

      if text =~ /\Assh:\/\/git@github\.com\/([^\/]+)\/(.+?)(?:\.git)?\z/i
        return [$1, cleanup_repo_name($2)]
      end

      if text =~ /\A(?:https?|git):\/\/github\.com\/([^\/]+)\/([^\/\?#]+).*?\z/i
        return [$1, cleanup_repo_name($2)]
      end

      nil
    end

    def self.cleanup_repo_name(repo)
      repo.to_s.sub(/\.git\z/i, '').sub(/\/+\z/, '')
    end

    def initialize(plugin, directory)
      @plugin = plugin
      @directory = directory
    end

    def call
      @request_failed = false
      @latest_error = nil
      repository = github_repository
      return Result.new(nil, nil, :source_missing) unless repository

      source = github_repository_url(repository)
      version = latest_release_tag(repository)
      version ||= latest_git_tag(repository)
      version ||= latest_tag_from_github_tags_page(repository)

      return Result.new(version, source, nil) if text_present?(version)
      error = @latest_error || (@request_failed ? :request_failed : nil)
      return Result.new(nil, source, error) if error

      Result.new(nil, source, :version_unavailable)
    rescue StandardError
      Result.new(nil, nil, :request_failed)
    end

    private

    attr_reader :plugin, :directory

    def github_repository
      source_candidates.each do |url|
        repository = self.class.github_repository_from_url(url)
        return repository if repository
      end

      nil
    end

    def source_candidates
      candidates = []
      candidates << plugin.url if plugin.respond_to?(:url)
      candidates << git_remote_url
      candidates.compact
    end

    def git_remote_url
      config_path = git_config_path
      return nil unless config_path && File.file?(config_path)

      remote_name = nil
      fallback_url = nil

      File.readlines(config_path).each do |line|
        if line =~ /^\s*\[remote "([^"]+)"\]/
          remote_name = $1
        elsif line =~ /^\s*url\s*=\s*(.+?)\s*$/
          url = $1.strip
          return url if remote_name == 'origin'
          fallback_url ||= url
        end
      end

      fallback_url
    rescue Errno::EACCES, Errno::ENOENT, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      nil
    end

    def git_config_path
      return nil unless text_present?(directory)

      dot_git = File.join(directory, '.git')
      return File.join(dot_git, 'config') if File.directory?(dot_git)
      return nil unless File.file?(dot_git)

      content = File.read(dot_git)
      match = content.match(/\Agitdir:\s*(.+?)\s*\z/)
      return nil unless match

      File.join(File.expand_path(match[1].strip, directory), 'config')
    rescue Errno::EACCES, Errno::ENOENT
      nil
    end

    def latest_release_tag(repository)
      data = get_json(github_api_url(repository, '/releases/latest'), :ignore_not_found => true)
      return nil unless data.is_a?(Hash)

      data['tag_name'] || data['name']
    end

    def latest_git_tag(repository)
      data = get_json(github_api_url(repository, '/tags?per_page=1'))
      return nil unless data.is_a?(Array) && data.first.is_a?(Hash)

      data.first['name']
    end

    def latest_tag_from_github_tags_page(repository)
      html = get_text(github_repository_url(repository) + '/tags')
      return nil unless text_present?(html)

      owner, repo = repository
      release_path = Regexp.escape("/#{owner}/#{repo}/releases/tag/")
      match = html.match(/href=["']#{release_path}([^"'#?]+)["']/i)
      return cleanup_html_tag(match[1]) if match

      tree_path = Regexp.escape("/#{owner}/#{repo}/tree/")
      match = html.match(/href=["']#{tree_path}([^"'#?]+)["']/i)
      match && cleanup_html_tag(match[1])
    end

    def cleanup_html_tag(value)
      text = value.to_s.gsub('&amp;', '&')
      URI.decode_www_form_component(text)
    rescue StandardError
      value.to_s
    end

    def get_text(url)
      uri = URI.parse(url)
      response = nil

      Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https',
                                      :open_timeout => TIMEOUT_SECONDS,
                                      :read_timeout => TIMEOUT_SECONDS) do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        request['User-Agent'] = USER_AGENT
        response = http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        set_http_error(response)
        return nil
      end

      response.body
    rescue StandardError => e
      set_error(error_from_exception(e))
      nil
    end
    def get_json(url, options = {})
      uri = URI.parse(url)
      response = nil

      Net::HTTP.start(uri.host, uri.port, :use_ssl => uri.scheme == 'https',
                                      :open_timeout => TIMEOUT_SECONDS,
                                      :read_timeout => TIMEOUT_SECONDS) do |http|
        request = Net::HTTP::Get.new(uri.request_uri)
        request['User-Agent'] = USER_AGENT
        request['Accept'] = 'application/vnd.github+json'
        response = http.request(request)
      end

      unless response.is_a?(Net::HTTPSuccess)
        set_http_error(response) unless response.is_a?(Net::HTTPNotFound) && options[:ignore_not_found]
        return nil
      end

      JSON.parse(response.body)
    rescue StandardError => e
      set_error(error_from_exception(e))
      nil
    end

    def set_http_error(response)
      case response
      when Net::HTTPUnauthorized
        set_error(:authentication_required)
      when Net::HTTPForbidden
        remaining = response['x-ratelimit-remaining'].to_s
        set_error(remaining == '0' ? :rate_limited : :authentication_required)
      when Net::HTTPNotFound
        set_error(:repository_not_found)
      else
        set_error(:request_failed)
      end
    end

    def set_error(error)
      @request_failed = true
      @latest_error ||= error
    end

    def error_from_exception(error)
      return :request_timeout if defined?(Timeout::Error) && error.is_a?(Timeout::Error)
      return :ssl_error if defined?(OpenSSL::SSL::SSLError) && error.is_a?(OpenSSL::SSL::SSLError)

      :request_failed
    end

    def github_api_url(repository, path)
      owner, repo = repository
      "https://api.github.com/repos/#{owner}/#{repo}#{path}"
    end

    def github_repository_url(repository)
      owner, repo = repository
      "https://github.com/#{owner}/#{repo}"
    end

    def text_present?(value)
      !value.to_s.strip.empty?
    end
  end
end

