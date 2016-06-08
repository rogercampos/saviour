require 'spec_helper'

describe Saviour::Config do
  describe "#storage" do
    it do
      expect { Saviour::Config.storage.anything }.to raise_error(RuntimeError)
    end

    it do
      Saviour::Config.storage = :test
      expect(Saviour::Config.storage).to eq :test
    end

    it "is thread-safe" do
      (0.upto(1_000)).map do |x|
        Thread.new do
          Saviour::Config.storage = x
          sleep 0.05 # Simulate work
          expect(Saviour::Config.storage).to eq x
        end
      end.each(&:join)
    end
  end
end