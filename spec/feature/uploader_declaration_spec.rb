require 'spec_helper'

describe "uploader declaration" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  it "raises exception if not provided either way" do
    expect {
      klass = Class.new(Test) { include Saviour::Model }
      klass.attach_file :file
    }.to raise_error.with_message "you must provide either an UploaderClass or a block to define it."
  end

  it "lets you provide uploader as a class" do
    uploader = Class.new(Saviour::BaseUploader) {
      store_dir { "/store/dir" }
      process { |contents, filename| [contents, "foo_#{filename}"] }
    }
    klass = Class.new(Test) { include Saviour::Model }
    klass.attach_file :file, uploader
    a = klass.create! file: Saviour::StringSource.new("content", "houhou.txt")

    expect(a.file.filename).to eq "foo_houhou.txt"
    expect(a.file.url).to eq 'http://domain.com/store/dir/foo_houhou.txt'
  end

  it "lets you provide uploader as a block" do
    klass = Class.new(Test) { include Saviour::Model }

    klass.attach_file(:file) do
      store_dir { "/store/dir" }
      process { |contents, filename| [contents, "foo_#{filename}"] }
    end
    a = klass.create! file: Saviour::StringSource.new("content", "houhou.txt")

    expect(a.file.filename).to eq "foo_houhou.txt"
    expect(a.file.url).to eq 'http://domain.com/store/dir/foo_houhou.txt'
  end
end
