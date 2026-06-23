module RedminePluginCheck
  class VersionRequirement
    def initialize(requirement)
      @requirement = requirement
    end

    def satisfied_by?(version)
      target = Gem::Version.new(clean_version(version))
      constraints = parsed_constraints

      return nil if constraints.empty?

      constraints.all? do |operator, required_version|
        compare(target, operator, Gem::Version.new(clean_version(required_version)))
      end
    end

    def lower_bound_only?
      constraints = parsed_constraints
      return false if constraints.empty?

      constraints.all? do |operator, _required_version|
        operator == '>=' || operator == '>'
      end
    end

    def minimum_version
      versions = parsed_constraints.map do |operator, required_version|
        if operator == '>=' || operator == '>'
          Gem::Version.new(clean_version(required_version))
        end
      end.compact

      versions.sort.last
    end

    private

    attr_reader :requirement

    def parsed_constraints
      parse_constraints(requirement)
    end

    def parse_constraints(value)
      case value
      when Hash
        parse_hash(value)
      when Array
        value.flat_map { |item| parse_constraints(item) }
      else
        parse_string(value.to_s)
      end
    end

    def parse_hash(hash)
      hash.flat_map do |key, value|
        case key.to_sym
        when :version_or_higher
          [['>=', value]]
        when :version
          [['==', value]]
        else
          []
        end
      end
    end

    def parse_string(value)
      text = value.strip
      return [] if text.empty?

      if text.include?('version_or_higher')
        version = text[/version_or_higher:\s*['"]([^'"]+)['"]/, 1] ||
                  text[/:version_or_higher\s*=>\s*['"]([^'"]+)['"]/, 1]
        return version ? [['>=', version]] : []
      end

      if text.include?('version:')
        version = text[/version:\s*['"]([^'"]+)['"]/, 1]
        return version ? [['==', version]] : []
      end

      if text.include?(':version')
        version = text[/:version\s*=>\s*['"]([^'"]+)['"]/, 1]
        return version ? [['==', version]] : []
      end

      text.scan(/(>=|<=|>|<|==|=|~>)?\s*([0-9]+(?:\.[0-9A-Za-z]+)*)/).map do |operator, version|
        [operator.to_s.empty? ? '==' : operator, version]
      end
    end

    def compare(target, operator, required)
      case operator
      when '>=', nil
        target >= required
      when '>'
        target > required
      when '<='
        target <= required
      when '<'
        target < required
      when '=', '=='
        target == required
      when '~>'
        target >= required && target < pessimistic_upper_bound(required)
      else
        false
      end
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
