require 'spec_helper'

describe Saviour::Processors::Digest do
  describe "#digest_filename" do
    subject {
      class Test
        include Saviour::Processors::Digest
      end.new
    }

    let(:filename) { "name.jpg" }
    let(:contents) { "bynary contents for a file" }

    it do
      _, new_name = subject.digest_filename(contents, filename)
      expect(new_name).to eq "name-ab54d187b7909ff4bba34777073d4654.jpg"
    end

    it do
      _, new_name = subject.digest_filename(contents, filename, separator: '/')
      expect(new_name).to eq "name/ab54d187b7909ff4bba34777073d4654.jpg"
    end
  end
end
