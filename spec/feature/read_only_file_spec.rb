require 'spec_helper'

describe "direct usage of ReadOnlyFile" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  let(:uploader) {
    Class.new(Saviour::BaseUploader) do
      store_dir { "/store/dir" }
    end
  }

  let(:klass) {
    klass = Class.new(Test) { include Saviour::Model }
    klass.attach_file :file, uploader
    klass
  }

  it "can be created" do
    a = klass.create! file: Saviour::StringSource.new("contents", "file.txt")

    path = a[:file]

    read_only_file = Saviour::ReadOnlyFile.new(path, klass.uploader_classes[:file].storage)

    expect(read_only_file.read).to eq "contents"
    expect(read_only_file.public_url).to eq "http://domain.com/store/dir/file.txt"
  end
end