require 'spec_helper'

describe "uploader declaration" do
  let!(:default_storage) do
    Saviour::LocalStorage.new(
      local_prefix: @tmpdir,
      public_url_prefix: "http://domain.com"
    )
  end

  let!(:custom_storage) do
    Saviour::LocalStorage.new(
      local_prefix: @tmpdir,
      public_url_prefix: "http://custom-domain.com"
    )
  end

  before { allow(Saviour::Config).to receive(:storage).and_return(default_storage) }

  it "lets you override storage on attachment basis" do
    klass = Class.new(Test) { include Saviour::Model }
    kustom_storage = custom_storage

    klass.attach_file(:file) do
      store_dir { "/store/dir" }
    end

    klass.attach_file(:file_thumb) do
      store_dir { "/store/dir" }
      with_storage kustom_storage
    end

    a = klass.create!(
      file: Saviour::StringSource.new("content", "houhou.txt"),
      file_thumb: Saviour::StringSource.new("content", "custom_houhou.txt")
    )

    expect(a.file.filename).to eq "houhou.txt"
    expect(a.file.url).to eq 'http://domain.com/store/dir/houhou.txt'

    expect(a.file_thumb.filename).to eq "custom_houhou.txt"
    expect(a.file_thumb.url).to eq 'http://custom-domain.com/store/dir/custom_houhou.txt'
  end
end
