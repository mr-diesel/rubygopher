require "dry/operation/extensions/active_record"

module Aggregator
  module Operations
    # Links a vacancy to dictionary skills found in its title, description and the
    # boards' tags, plus the skill matching its language. Idempotent: rerunning replaces
    # the dictionary-derived links and never touches manually added ones.
    class ExtractSkills < Dry::Operation
      include Dry::Operation::Extensions::ActiveRecord

      def initialize(matcher: SkillMatcher.new)
        @matcher = matcher
      end

      def call(vacancy, now: Time.current)
        skills = step find_skills(vacancy)

        transaction do
          vacancy.vacancy_skills.dictionary.where.not(skill_id: skills.map(&:id)).delete_all
          present = vacancy.vacancy_skills.pluck(:skill_id)
          vacancy.vacancy_skills.create!((skills.reject { |skill| present.include?(skill.id) }).map { |skill| { skill: skill, source: :dictionary } })
          vacancy.update!(skills_extracted_at: now)
        end
        skills
      end

      private

      def find_skills(vacancy)
        text = [ vacancy.title, vacancy.description, *vacancy.postings.flat_map(&:tags) ].join("\n")
        Success((@matcher.match(text) + Skill.where(slug: vacancy.language).to_a).uniq)
      end
    end
  end
end
