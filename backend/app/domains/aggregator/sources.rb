module Aggregator
  # Recognises job-board vacancy URLs so a pasted link maps to (source, external_id).
  module Sources
    PATTERNS = {
      "hh" => %r{\Ahttps?://(?:[\w-]+\.)?hh\.ru/vacancy/(\d+)}i,
      "habr_career" => %r{\Ahttps?://career\.habr\.com/vacancies/(\d+)}i,
      "getmatch" => %r{\Ahttps?://getmatch\.ru/vacancies/(\d+)}i,
      "hirify" => %r{\Ahttps?://hirify\.me/jobs/(\d+)}i
    }.freeze

    def self.parse(url)
      PATTERNS.each do |source, pattern|
        match = pattern.match(url.to_s.strip)
        return { source: source, external_id: match[1] } if match
      end
      nil
    end
  end
end
