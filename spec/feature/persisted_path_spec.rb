require 'spec_helper'

describe "persisted path" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  context "can change the default_path on the uploader and previous instances are not affected" do
    it do
      uploader = Class.new(Saviour::BaseUploader) { store_dir { "/store/dir" } }
      klass = Class.new(Test) { include Saviour }
      klass.attach_file :file, uploader

      with_test_file("example.xml") do |example|
        a = klass.create!
        expect(a.update_attributes(file: example)).to be_truthy
        expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy
        expect(File.dirname(a[:file])).to eq "/store/dir"


        uploader.class_eval { store_dir { "/another/dir" } }

        with_test_file("camaloon.jpg") do |example_2|
          b = klass.create!
          expect(b.update_attributes(file: example_2)).to be_truthy

          expect(Saviour::Config.storage.exists?(b[:file])).to be_truthy
          expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy

          expect(File.dirname(b[:file])).to eq "/another/dir"
          expect(File.dirname(a[:file])).to eq "/store/dir"
        end
      end
    end
  end
end
