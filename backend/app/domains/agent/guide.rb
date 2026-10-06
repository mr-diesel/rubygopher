module Agent
  module Guide
    PATH = Rails.root.join("app/domains/agent/GUIDE.md")

    def self.text
      File.read(PATH)
    end
  end
end
