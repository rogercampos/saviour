require 'spec_helper'

describe "#with_copy" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  let(:uploader) do
    Class.new(Saviour::BaseUploader) {
      store_dir { "/store/dir" }
      process { |contents, filename| [contents, "foo_#{filename}"] }
    }
  end

  let(:klass) do
    klass = Class.new(Test) { include Saviour::Model }
    klass.attach_file :file, uploader
    klass
  end

  it "provides a copy of the stored file" do
    a = klass.create! file: Saviour::StringSource.new("some contents", "houhou.txt")
    a.file.with_copy do |tmpfile|
      expect(tmpfile.read).to eq "some contents"
    end
  end

  it "deletes the copied file even on exception" do
    test_exception = Class.new(StandardError)

    a = klass.create! file: Saviour::StringSource.new("some contents", "houhou.txt")
    path = nil

    begin
      a.file.with_copy do |f|
        path = f.path
        expect(File.file?(path)).to be_truthy
        raise(test_exception, "some exception within the block")
      end
    rescue test_exception
    end

    expect(File.file?(path)).to be_falsey
  end
end
