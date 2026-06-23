module RedminePluginCheck
  class VersionRequirement
    def initialize(requirement)
      @requirement = requirement
    end

    def satisfied_by?(version)
      target = clean_version(version)
      groups = parsed_constraint_groups

      return nil if groups.empty?

      groups.any? do |constraints|
        constraints.all? do |operator, required_version|
          compare(target, operator, clean_version(required_version))
        end
      end
    end

    def lower_bound_only?
      groups = parsed_constraint_groups
      return false if groups.empty?

      groups.all? do |constraints|
        constraints.any? && constraints.all? do |operator, _required_version|
          operator == :version_or_higher || operator == '>=' || operator == '>'
        end
      end
    end

    def minimum_version
      versions = parsed_constraint_groups.flatten(1).map do |operator, required_version|
        if operator == :version_or_higher || operator == '>=' || operator == '>'
          Gem::Version.new(clean_version(required_version))
        end
      end.compact

      versions.sort.last
    end

    private

    attr_reader :requirement

    def parsed_constraint_groups
      parse_constraint_groups(requirement)
    end

    def parse_constraint_groups(value)
      case value
      when Hash
        parse_hash(value)
      when Array
        value.flat_map { |item| parse_constraint_groups(item) }
      else
        parse_string(value.to_s)
      end
    end

    def parse_hash(hash)
      hash.flat_map do |key, value|
        case key.to_sym
        when :version_or_higher
          [[[:version_or_higher, value]]]
        when :version
          parse_redmine_version_value(value)
        else
          []
        end
      end
    end

    def parse_redmine_version_value(value)
      case value
      when Range
        [[[:redmine_gte, value.first], [:redmine_lte, value.last]]]
      when Array
        value.map { |version| [[:redmine_eq, version]] }
      else
        [[[:redmine_eq, value]]]
      end
    end

    def parse_string(value)
      text = value.strip
      return [] if text.empty?

      version_or_higher = extract_keyed_version(text, 'version_or_higher')
      return [[[:version_or_higher, version_or_higher]]] if version_or_higher

      range = extract_version_range(text)
      return [[[:redmine_gte, range.first], [:redmine_lte, range.last]]] if range

      array = extract_version_array(text)
      return array.map { |version| [[:redmine_eq, version]] } if array.any?

      keyed_version = extract_keyed_version(text, 'version')
      return [[[:redmine_eq, keyed_version]]] if keyed_version

      operator_constraints = parse_operator_constraints(text)
      return [operator_constraints] if operator_constraints.any?

      bare_version = extract_bare_version(text)
      return [[[:version_or_higher, bare_version]]] if bare_version

      []
    end

    def extract_keyed_version(text, key)
      patterns = [
        /#{key}:\s*['"]([^'"]+)['"]/,
        /:#{key}\s*=>\s*['"]([^'"]+)['"]/
      ]

      patterns.each do |pattern|
        match = text.match(pattern)
        return match[1] if match
      end

      nil
    end

    def extract_version_range(text)
      match = text.match(/['"]([^'"]+)['"]\s*\.\.\s*['"]([^'"]+)['"]/) ||
              text.match(/:version\s*=>\s*([^\s]+)\s*\.\.\s*([^\s]+)/)
      return nil unless match

      Range.new(match[1], match[2])
    end

    def extract_version_array(text)
      match = text.match(/\[([^\]]+)\]/)
      return [] unless match

      match[1].scan(/['"]([^'"]+)['"]/).flatten
    end

    def parse_operator_constraints(text)
      return [] unless text =~ /(>=|<=|>|<|==|=|~>)/

      text.scan(/(>=|<=|>|<|==|=|~>)\s*([0-9]+(?:\.[0-9A-Za-z]+)*)/).map do |operator, version|
        [operator, version]
      end
    end

    def extract_bare_version(text)
      match = text.match(/\A['"]?([0-9]+(?:\.[0-9A-Za-z]+)*)['"]?\z/)
      match && match[1]
    end

    def compare(target, operator, required)
      case operator
      when :version_or_higher
        redmine_compare(required, target) <= 0
      when :redmine_eq
        redmine_compare(required, target) == 0
      when :redmine_gte
        redmine_compare(required, target) <= 0
      when :redmine_lte
        redmine_compare(required, target) >= 0
      when '>=', nil
        gem_version(target) >= gem_version(required)
      when '>'
        gem_version(target) > gem_version(required)
      when '<='
        gem_version(target) <= gem_version(required)
      when '<'
        gem_version(target) < gem_version(required)
      when '=', '=='
        gem_version(target) == gem_version(required)
      when '~>'
        target_version = gem_version(target)
        required_version = gem_version(required)
        target_version >= required_version && target_version < pessimistic_upper_bound(required_version)
      else
        false
      end
    end

    def redmine_compare(requirement_version, target_version)
      requirement_parts = version_parts(requirement_version)
      target_parts = version_parts(target_version)
      requirement_parts <=> target_parts[0, requirement_parts.size]
    end

    def version_parts(value)
      clean_version(value).split('.').map { |part| part.to_i }
    end

    def gem_version(value)
      Gem::Version.new(clean_version(value))
    end

    def pessimistic_upper_bound(version)
      segments = version.segments

      if segments.length <= 1
        Gem::Version.new((segments.first + 1).to_s)
      else
        upper_segments = segments[0..-2]
        upper_segments[-1] += 1
        Gem::Version.new(upper_segments.join('.'))
      end
    end

    def clean_version(value)
      value.to_s.strip.sub(/\Av/i, '')
    end
  end
end
