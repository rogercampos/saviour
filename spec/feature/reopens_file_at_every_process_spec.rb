require 'spec_helper'

describe "file information" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  let(:uploader) {
    Class.new(Saviour::BaseUploader) do
      store_dir { "/store/dir/#{model.id}" }
      process_with_file do |file, name|
        model.result1 = file.stat.size

        path = file.path

        # Assign new contents on the same path, forcing a new inode
        ::File.delete(path)
        ::File.write(path, "SOME NEW DATA, LONGER")

        [file, name]
      end

      process_with_file do |file, name|
        model.result2 = file.stat.size # This must be the size of the new contents

        [file, name]
      end
    end
  }

  let(:klass) {
    klass = Class.new(Test) {
      attr_accessor :result1, :result2
      include Saviour::Model
    }
    klass.attach_file :file, uploader
    klass
  }

  it "is renewed at every process_with_file, clearing stale data on the file instance" do
    f = Tempfile.new("test")
    f.write("original") # 8 bytes
    f.flush

    a = klass.create! file: f
    expect(a.result1).to eq 8
    expect(a.result2).to eq 21

    f.close!
  end
end