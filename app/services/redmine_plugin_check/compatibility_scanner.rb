module RedminePluginCheck
  class CompatibilityScanner
    Finding = Struct.new(:key, :severity, :path, :line)

    MAX_FILE_SIZE = 512 * 1024
    SKIPPED_DIRECTORIES = %w[.git log tmp vendor node_modules test spec].freeze
    SCANNED_EXTENSIONS = %w[.rb .erb .rake .ru .gemspec].freeze
    SCANNED_BASENAMES = %w[Gemfile Rakefile config.ru].freeze
    SKIPPED_BASENAMES = %w[compatibility_scanner.rb].freeze

    PATTERNS = [
      [:alias_method_chain, 'risky', /\balias_method_chain\b\s+[:'\"A-Za-z_]/],
      [:dispatcher_to_prepare, 'risky', /\bDispatcher\.to_prepare\b/],
      [:require_dispatcher, 'risky', /require_dependency\s+['"]dispatcher['"]/],
      [:before_filter, 'warning', /\b(before_filter|after_filter|around_filter)\b/],
      [:unloadable, 'warning', /\bunloadable\b/],
      [:attr_accessible, 'warning', /\battr_accessible\b/],
      [:active_record_observer, 'warning', /\bActiveRecord::Observer\b/],
      [:monkey_patch_include, 'warning', /\.send\s*\(\s*:include\b|\.send\s*\(\s*['"]include['"]/]
    ].freeze

    def initialize(directory)
      @directory = directory.to_s
    end

    def call
      findings = []

      scanned_files.each do |path|
        content = scanner_content(path)
        next if content.nil?

        content.lines.each_with_index do |line, index|
          PATTERNS.each do |key, severity, pattern|
            if line =~ pattern
              findings << Finding.new(key, severity, relative_path(path), index + 1)
            end
          end
        end
      end

      unique_findings(findings)
    end

    private

    attr_reader :directory

    def scanned_files
      return [] unless Dir.exist?(directory)

      Dir.glob(File.join(directory, '**', '*')).select do |path|
        File.file?(path) && scanned_file?(path)
      end
    end

    def scanned_file?(path)
      normalized = path.tr('\\', '/')
      return false if skipped_path?(normalized)
      return false if File.size(path) > MAX_FILE_SIZE

      basename = File.basename(path)
      extension = File.extname(path)
      return false if SKIPPED_BASENAMES.include?(basename)

      SCANNED_BASENAMES.include?(basename) || SCANNED_EXTENSIONS.include?(extension)
    rescue Errno::ENOENT, Errno::EACCES
      false
    end

    def skipped_path?(normalized_path)
      SKIPPED_DIRECTORIES.any? do |directory_name|
        normalized_path.include?("/#{directory_name}/")
      end
    end

    def scanner_content(path)
      content = read_file(path)
      return nil if content.nil?

      strip_comments(path, content)
    end

    def strip_comments(path, content)
      extension = File.extname(path)
      basename = File.basename(path)

      if %w[.rb .rake .gemspec .ru].include?(extension) || %w[Gemfile Rakefile config.ru].include?(basename)
        return content.lines.map { |line| line =~ /^\s*#/ ? "\n" : line }.join
      end

      if extension == '.erb'
        return content.gsub(/<%#.*?%>/m) { |match| "\n" * match.count("\n") }
                      .gsub(/<!--.*?-->/m) { |match| "\n" * match.count("\n") }
      end

      content
    end
    def read_file(path)
      File.read(path)
    rescue Errno::ENOENT, Errno::EACCES, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      nil
    end

    def relative_path(path)
      path.sub(/\A#{Regexp.escape(directory)}[\\\/]?/, '')
    end

    def unique_findings(findings)
      seen = {}
      findings.each_with_object([]) do |finding, unique|
        key = [finding.key, finding.path, finding.line]
        next if seen[key]

        seen[key] = true
        unique << finding
      end
    end
  end
end
