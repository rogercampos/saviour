require 'spec_helper'

describe "access to model data from uploaders" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  let(:uploader) {
    Class.new(Saviour::BaseUploader) do
      store_dir { "/store/dir/#{model.id}" }
      process { |contents, name| [contents, "#{model.id}-#{attached_as}-#{name}"] }
    end
  }

  let(:klass) {
    klass = Class.new {
      include Saviour::BasicModel

      def id
        87
      end
    }
    klass.attach_file :file, uploader
    klass
  }

  describe "file store" do
    it do
      with_test_file("example.xml") do |example, name|
        a = klass.new
        a.file = example
        path = a.file.write

        expect(Saviour::Config.storage.exists?(path)).to be_truthy
        expect(path).to eq "/store/dir/87/87-file-#{name}"
      end
    end
  end
end
