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

    describe "threading behaviour" do
      it "is thread-safe" do
        (0.upto(1_000)).map do |x|
          Thread.new do
            Saviour::Config.storage = x
            sleep 0.05 # Simulate work
            expect(Saviour::Config.storage).to eq x
          end
        end.each(&:join)
      end

      it "provides main value on new threads" do
        Saviour::Config.storage = "chuck"
        Thread.new { expect(Saviour::Config.storage).to eq("chuck") }.join
      end

      it "allows per-thread values" do
        Saviour::Config.storage = 12
        Thread.new do
          Saviour::Config.storage = :foo
          expect(Saviour::Config.storage).to eq :foo
        end.join
        expect(Saviour::Config.storage).to eq 12
      end
    end
  end
end