require 'json'
require 'net/http'
require 'openssl'
require 'timeout'
require 'uri'

module RedmineUpgradeAdvisor
  class LatestVersionChecker
    Result = Struct.new(:version, :source, :error)

    USER_AGENT = 'RedmineUpgradeAdvisor/0.1'.freeze
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
      repository = github_repository
      return Result.new(nil, nil, :source_missing) unless repository

      source = github_repository_url(repository)
      version = latest_release_tag(repository)
      version ||= latest_git_tag(repository)

      return Result.new(version, source, nil) if text_present?(version)

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
      data = get_json(github_api_url(repository, '/releases/latest'))
      return nil unless data.is_a?(Hash)

      data['tag_name'] || data['name']
    end

    def latest_git_tag(repository)
      data = get_json(github_api_url(repository, '/tags?per_page=1'))
      return nil unless data.is_a?(Array) && data.first.is_a?(Hash)

      data.first['name']
    end

    def get_json(url)
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

      return nil unless response.is_a?(Net::HTTPSuccess)

      JSON.parse(response.body)
    rescue StandardError
      nil
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
