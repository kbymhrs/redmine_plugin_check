module RedminePluginCheck
  class MarkdownFormatter
    FENCE_PATTERN = /\A\s*```(?:markdown|md)?\s*\z/i.freeze

    def initialize(markdown)
      @markdown = markdown.to_s
    end

    def call
      lines = normalized_lines
      lines = strip_standalone_fences(lines)
      lines = normalize_list_markers(lines)
      lines = normalize_block_spacing(lines)
      lines.join("\n").strip + "\n"
    end

    private

    attr_reader :markdown

    def normalized_lines
      markdown.gsub("\r\n", "\n").gsub("\r", "\n").lines.map(&:chomp)
    end

    def strip_standalone_fences(lines)
      lines.reject { |line| line =~ FENCE_PATTERN }
    end

    def normalize_list_markers(lines)
      lines.map do |line|
        line.sub(/\A(\s*)\*\s+/, '\\1- ')
      end
    end

    def normalize_block_spacing(lines)
      result = []

      lines.each do |line|
        stripped = line.strip

        if heading?(stripped) || horizontal_rule?(stripped)
          append_blank(result)
          result << stripped
          append_blank(result)
          next
        end

        if list_item?(stripped) && result.any? && !result.last.to_s.empty? && !list_item?(result.last.to_s.strip)
          append_blank(result)
        elsif !list_item?(stripped) && result.any? && list_item?(result.last.to_s.strip)
          append_blank(result)
        end

        result << line.rstrip
      end

      trim_blank_edges(result)
    end

    def heading?(line)
      line =~ /\A\#{1,6}\s+\S/
    end

    def horizontal_rule?(line)
      line =~ /\A(?:-{3,}|\*{3,}|_{3,})\z/
    end

    def list_item?(line)
      line =~ /\A(?:[-+]\s+|\d+\.\s+)/
    end

    def append_blank(lines)
      lines << '' unless lines.empty? || lines.last.to_s.empty?
    end

    def trim_blank_edges(lines)
      lines.shift while lines.first.to_s.empty?
      lines.pop while lines.last.to_s.empty?
      lines
    end
  end
end