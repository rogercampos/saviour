require 'spec_helper'

describe "access to model data from uploaders" do
  before { Saviour::Config.storage = Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com") }
  after { Saviour::Config.storage = nil }

  let(:uploader) {
    Class.new(Saviour::BaseUploader) do
      store_dir { "/store/dir/#{model.id}" }
      process { |contents, name| [contents, "#{model.id}-#{attached_as}-#{name}"] }
    end
  }

  let(:klass) {
    a = Class.new(Text)
    a.attach_file :file, uploader
    a
  }

  describe "file store" do
    it do
      with_test_file("example.xml") do |example, name|
        a = klass.create! id: 87
        expect(a.update_attributes(file: example)).to be_truthy
        expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy
        expect(a[:file]).to eq "/store/dir/87/87-file-#{name}"
      end
    end
  end
end
