require 'spec_helper'

describe Saviour::Config do
  after { Saviour::Config.storage = nil }
  
  describe "#storage" do
    it do
      expect { Saviour::Config.storage }.to raise_error(RuntimeError)
    end

    it do
      Saviour::Config.storage = :test
      expect(Saviour::Config.storage).to eq :test
    end
  end
end