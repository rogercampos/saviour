require 'spec_helper'

describe "access to model data from uploaders" do
  before { Saviour::Config.storage = Saviour::FileStorage.new(local_prefix: @tmpdir, public_uri_prefix: "http://domain.com") }
  after { Saviour::Config.storage = nil }

  class C < Test
    class TestUploader < Saviour::BaseUploader
      store_dir! { "/store/dir/#{model.id}" }
      run { |contents, name| [contents, "#{model.id}-#{mounted_as}-#{name}"] }
    end

    include Saviour
    attach_file :file, TestUploader
  end

  describe "file store" do
    it do
      with_test_file("example.xml") do |example, name|
        a = C.create! id: 87
        expect(a.update_attributes(file: example)).to be_truthy
        expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy
        expect(a[:file]).to eq "/store/dir/87/87-file-#{name}"
      end
    end
  end
end
