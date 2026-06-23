module RedminePluginCheck
  class Analyzer
    Result = Struct.new(
      :redmine_version,
      :ruby_version,
      :rails_version,
      :target_version,
      :plugins
    )

    PluginReport = Struct.new(
      :id,
      :name,
      :version,
      :latest_version,
      :latest_version_source,
      :latest_version_error,
      :author,
      :last_modified_at,
      :requires_redmine,
      :requires_redmine_satisfied,
      :requires_redmine_lower_bound_only,
      :target_major_jump,
      :redmine_condition_in_init,
      :has_migrations,
      :has_gemfile,
      :compatibility_findings,
      :status,
      :notes
    )

    REDMINE_VERSION_PATTERN = /
      Redmine(::VERSION|\.version|\.release)|
      Gem::Version\.new\([^)]*Redmine
    /ix.freeze

    def initialize(options = {})
      @target_version = normalize_text(options[:target_version])
      @plugins = options[:plugins]
      @plugins_path = options[:plugins_path]
      @check_latest = options[:check_latest] ? true : false
      @latest_checker = options[:latest_checker]
    end

    def call
      Result.new(
        redmine_version,
        RUBY_VERSION,
        Rails.version,
        target_version,
        installed_plugins.map { |plugin| analyze_plugin(plugin) }
      )
    end

    private

    attr_reader :target_version, :plugins, :plugins_path, :check_latest, :latest_checker

    def installed_plugins
      Array(plugins || Redmine::Plugin.all).sort_by { |plugin| plugin.id.to_s }
    end

    def analyze_plugin(plugin)
      requires_redmine_value = extract_requires_redmine(plugin)
      requires_redmine = requirement_to_text(requires_redmine_value)
      requires_result = evaluate_requires_redmine(requires_redmine_value)
      lower_bound_only = lower_bound_only_requirement?(requires_redmine_value)
      target_major_jump = target_major_version_jump?
      directory = plugin_directory(plugin)
      init_path = File.join(directory, 'init.rb')
      has_migrations = Dir.exist?(File.join(directory, 'db', 'migrate'))
      has_gemfile = File.file?(File.join(directory, 'Gemfile'))
      has_init_condition = redmine_condition_in_init?(init_path)
      compatibility_findings = CompatibilityScanner.new(directory).call
      last_modified_at = plugin_last_modified_at(directory)
      latest_version = latest_version_for(plugin, directory)
      notes = build_notes(
        requires_redmine,
        requires_result,
        lower_bound_only,
        target_major_jump,
        has_init_condition,
        has_migrations,
        has_gemfile,
        compatibility_findings
      )

      PluginReport.new(
        plugin.id.to_s,
        normalize_text(plugin.name),
        normalize_text(plugin.version),
        latest_version.version,
        latest_version.source,
        latest_version.error,
        normalize_text(plugin.author),
        last_modified_at,
        requires_redmine,
        requires_result,
        lower_bound_only,
        target_major_jump,
        has_init_condition,
        has_migrations,
        has_gemfile,
        compatibility_findings,
        status_for(
          requires_redmine,
          requires_result,
          lower_bound_only,
          target_major_jump,
          has_init_condition,
          has_migrations,
          has_gemfile,
          compatibility_findings
        ),
        notes
      )
    end

    def latest_version_for(plugin, directory)
      return empty_latest_version unless check_latest

      result =
        if latest_checker
          latest_checker.call(plugin, directory)
        else
          LatestVersionChecker.new(plugin, directory).call
        end

      result || empty_latest_version
    rescue StandardError
      LatestVersionChecker::Result.new(nil, nil, :request_failed)
    end

    def empty_latest_version
      LatestVersionChecker::Result.new(nil, nil, nil)
    end

    def extract_requires_redmine(plugin)
      requirement = plugin_requires_redmine(plugin)

      return requirement if requirement_to_text(requirement).present?

      init_requires_redmine(plugin_directory(plugin))
    end

    def plugin_requires_redmine(plugin)
      if plugin.instance_variable_defined?(:@requires_redmine)
        return plugin.instance_variable_get(:@requires_redmine)
      end

      if plugin.respond_to?(:requires_redmine)
        begin
          return plugin.requires_redmine
        rescue ArgumentError, NoMethodError
          nil
        end
      end

      plugin.requires_redmine_version if plugin.respond_to?(:requires_redmine_version)
    end

    def init_requires_redmine(directory)
      init_path = File.join(directory, 'init.rb')
      return nil unless File.file?(init_path)

      content = File.read(init_path)
      match = content.match(/requires_redmine\s+([^\n]+)/)
      normalize_text(match && match[1])
    rescue Errno::EACCES, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      nil
    end

    def evaluate_requires_redmine(requirement)
      return nil if target_version.blank? || requirement.blank?

      VersionRequirement.new(requirement).satisfied_by?(target_version)
    rescue ArgumentError
      nil
    end

    def lower_bound_only_requirement?(requirement)
      return false if requirement.blank?

      VersionRequirement.new(requirement).lower_bound_only?
    rescue ArgumentError
      false
    end

    def redmine_condition_in_init?(init_path)
      return false unless File.file?(init_path)

      !!(File.read(init_path) =~ REDMINE_VERSION_PATTERN)
    rescue Errno::EACCES, Encoding::InvalidByteSequenceError, Encoding::UndefinedConversionError
      false
    end

    def status_for(requires_redmine, requires_result, lower_bound_only, target_major_jump, has_init_condition, has_migrations, has_gemfile, compatibility_findings)
      return 'Risky' if requires_result == false
      return 'Risky' if breaking_legacy_findings?(compatibility_findings)
      return 'Warning' if compatibility_findings.any?
      return 'Warning' if has_init_condition || has_migrations || has_gemfile
      return 'OK' if requires_result == true
      return 'Unknown' if requires_redmine.blank? && !has_init_condition

      'Warning'
    end

    def build_notes(requires_redmine, requires_result, lower_bound_only, target_major_jump, has_init_condition, has_migrations, has_gemfile, compatibility_findings)
      notes = []
      notes << :requires_redmine_missing if requires_redmine.blank?
      notes << :target_version_outside_requires_redmine if requires_result == false
      notes << :requires_redmine_lower_bound_only if lower_bound_only
      notes << :legacy_compatibility_patterns_detected if compatibility_findings.any?
      notes << :legacy_breaking_patterns_detected if breaking_legacy_findings?(compatibility_findings)
      notes << :init_contains_redmine_version_condition if has_init_condition
      notes << :has_database_migrations if has_migrations
      notes << :has_plugin_gemfile if has_gemfile
      notes << :target_version_missing if target_version.blank?
      notes
    end

    def plugin_last_modified_at(directory)
      return nil unless Dir.exist?(directory)

      mtimes = Dir.glob(File.join(directory, '**', '*')).map do |path|
        next if ignored_last_modified_path?(path)
        next unless File.file?(path)

        File.mtime(path)
      end.compact

      mtimes.sort.last
    rescue Errno::EACCES, Errno::ENOENT
      nil
    end

    def ignored_last_modified_path?(path)
      normalized_path = path.tr('\\', '/')
      %w[/.git/ /log/ /tmp/ /vendor/ /node_modules/].any? do |ignored|
        normalized_path.include?(ignored)
      end
    end

    def breaking_legacy_findings?(compatibility_findings)
      return false unless target_major_at_least?(4)

      compatibility_findings.any? { |finding| finding.severity == 'risky' }
    end

    def target_major_version_jump?
      current_major = major_version(redmine_version)
      target_major = major_version(target_version)
      current_major && target_major && target_major > current_major
    end

    def target_major_at_least?(major)
      target_major = major_version(target_version)
      target_major && target_major >= major
    end

    def major_version(value)
      match = value.to_s.match(/\d+/)
      match && match[0].to_i
    end

    def plugin_directory(plugin)
      return plugin.directory.to_s if plugin.respond_to?(:directory) && plugin.directory.present?

      File.join(base_plugins_path, plugin.id.to_s)
    end

    def base_plugins_path
      plugins_path || Rails.root.join('plugins').to_s
    end

    def redmine_version
      if defined?(Redmine::VERSION::STRING)
        Redmine::VERSION::STRING
      elsif Redmine.respond_to?(:version)
        Redmine.version.to_s
      elsif defined?(Redmine::VERSION)
        Redmine::VERSION.to_s
      else
        nil
      end
    end

    def requirement_to_text(value)
      return nil if value.nil?

      if value.is_a?(Hash)
        value.map { |key, version| "#{key}: #{version.inspect}" }.join(', ')
      else
        normalize_text(value)
      end
    end

    def normalize_text(value)
      text = value.to_s.strip
      text.presence
    end
  end
end
