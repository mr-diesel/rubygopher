module Aggregator
  # Finds dictionary skills mentioned in free text: every Skill name and alias as a
  # whole word, case-insensitive, except terms shorter than MIN_INSENSITIVE_LENGTH
  # ("Go", "C") which are matched case-sensitively to avoid "go to the office".
  class SkillMatcher
    MIN_INSENSITIVE_LENGTH = 3

    def initialize(skills = Skill.all.to_a)
      @patterns = skills.to_h { |skill| [ skill, pattern_for(skill) ] }
    end

    def match(text)
      return [] if text.blank?

      @patterns.select { |_, pattern| pattern.match?(text) }.keys
    end

    private

    def pattern_for(skill)
      terms = [ skill.name, *skill.aliases ].map(&:strip).reject(&:empty?)
      sensitive, insensitive = terms.partition { |term| term.length < MIN_INSENSITIVE_LENGTH }
      alternatives = [
        (bounded(sensitive) if sensitive.any?),
        ("(?i:#{bounded(insensitive)})" if insensitive.any?)
      ].compact
      Regexp.new(alternatives.join("|"))
    end

    # Word boundaries that also work around "C++", "Node.js" and Cyrillic text.
    def bounded(terms)
      "(?<![[:alnum:]])(?:#{terms.map { |term| Regexp.escape(term) }.join("|")})(?![[:alnum:]])"
    end
  end
end
