require 'spec_helper'

describe "saving a new file" do
  before { Saviour::Config.storage = Saviour::FileStorage.new(local_prefix: @tmpdir, public_uri_prefix: "http://domain.com") }
  after { Saviour::Config.storage = nil }

  class D < Test
    class TestUploader < Saviour::BaseUploader
      store_dir! { "/store/dir" }

      version(:thumb) do
        store_dir! { "/versions/store/dir" }
      end
    end

    include Saviour
    attach_file :file, TestUploader, versions: [:thumb]
  end

  describe "creation after main file" do
    it do
      with_test_file("example.xml") do |example|
        a = D.create!
        expect(a.update_attributes(file: example)).to be_truthy
        expect(Saviour::Config.storage.exists?(a[:file_thumb])).to be_truthy
      end
    end
  end

  describe "deletion" do
    it do
      with_test_file("example.xml") do |example|
        a = D.create!
        a.update_attributes(file: example)
        expect(Saviour::Config.storage.exists?(a[:file_thumb])).to be_truthy
        expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy

        a.destroy
        expect(Saviour::Config.storage.exists?(a[:file_thumb])).to be_falsey
        expect(Saviour::Config.storage.exists?(a[:file])).to be_falsey
      end
    end
  end

  describe "changes following main file"
end
