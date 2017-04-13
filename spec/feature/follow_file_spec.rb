require 'spec_helper'

describe "Make one attachment follow another one" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  let(:uploader) {
    Class.new(Saviour::BaseUploader) do
      store_dir { "/store/dir" }
    end
  }

  let(:uploader_for_version) {
    Class.new(Saviour::BaseUploader) do
      store_dir { "/store/dir" }

      process do |contents, filename|
        [contents, "new_#{filename}"]
      end
    end
  }

  let(:klass) {
    a = Class.new(Test) { include Saviour::Model }
    a.attach_file :file, uploader
    a.attach_file :file_thumb, uploader_for_version, follow: :file
    a
  }

  describe "automatic assignation" do
    it "works when :file is assigned if previously empty" do
      a = klass.create! file: Saviour::StringSource.new("blabla", "cuca.xml")

      expect(a.file.filename).to eq "cuca.xml"
      expect(a.file_thumb.filename).to eq "new_cuca.xml"

      expect(a.file.read.bytesize).to eq 6
      expect(a.file_thumb.read.bytesize).to eq 6
    end

    it "does not override a previously assigned source" do
      a = klass.new
      a.file_thumb = StringIO.new("some contents without a filename")
      a.file = Saviour::StringSource.new("blabla", "cuca.xml")
      a.save!

      expect(a.file.filename).to eq "cuca.xml"
      expect(a.file_thumb.read).to eq "some contents without a filename"

      expect(a.file.read.bytesize).to eq 6
      expect(a.file_thumb.read.bytesize).to eq 32
    end
  end
end