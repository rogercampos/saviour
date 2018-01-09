require 'spec_helper'

describe "Original assigned file" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  let(:uploader) {
    Class.new(Saviour::BaseUploader) do
      store_dir { "/store/dir/#{model.id}" }
      process_with_path do |path, name|
        ::File.delete(path)

        f = Tempfile.new("test")
        f.write("Hello")
        f.flush
        f.close

        [f.path, name]
      end
    end
  }

  let(:klass) {
    klass = Class.new(Test) {
      include Saviour::Model
    }
    klass.attach_file :file, uploader
    klass
  }

  it "is preserved even after deleting the incoming file from a processor" do
    f = Tempfile.new("test")
    f.write("original")
    f.flush

    a = klass.create! file: f

    expect(a.file.read).to eq "Hello"

    expect(::File.file?(f.path)).to be_truthy
    expect(::File.read(f.path)).to eq "original"

    f.close!
  end
end