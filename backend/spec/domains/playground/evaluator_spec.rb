require "rails_helper"

RSpec.describe Playground::Evaluator do
  describe ".run" do
    it "returns what the snippet printed" do
      expect(described_class.run("print 'hi'; warn 'err'")).to eq(output: "hierr\n")
    end

    it "describes a raised error" do
      result = described_class.run("raise ArgumentError, 'boom'")

      expect(result[:error]).to include(class: "ArgumentError", message: "boom")
    end

    it "stops storing output past the limit" do
      result = described_class.run("200.times { print 'x' * 1000 }")

      expect(result[:output].bytesize).to be < described_class::MAX_OUTPUT + 100
      expect(result[:output]).to end_with("… truncated (100000 more bytes)")
    end

    it "keeps the first bytes of a capped stream" do
      result = described_class.run("print 'start'; print 'x' * #{described_class::MAX_OUTPUT}")

      expect(result[:output]).to start_with("start")
    end
  end
end
