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
    a.attach_file :file_thumb, uploader_for_version, follow: :file, dependent: :ignore
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

  describe "dependent destruction" do
    context "with dependent: :destroy" do
      let(:klass) {
        a = Class.new(Test) { include Saviour::Model }
        a.attach_file :file, uploader
        a.attach_file :file_thumb, uploader_for_version, follow: :file, dependent: :destroy
        a
      }

      it "removes followers" do
        a = klass.create! file: StringIO.new("some contents without a filename")
        expect(a.file_thumb.read).to eq "some contents without a filename"

        a.remove_file!
        expect(a.file_thumb?).to be_falsey
        expect(a.file_thumb.read).to be_nil
      end

      it "does not remove follower if it has been changed before destruction in a transaction" do
        a = klass.create! file: StringIO.new("some contents without a filename")
        expect(a.file_thumb.read).to eq "some contents without a filename"

        ActiveRecord::Base.transaction do
          a.file_thumb = StringIO.new("replaced contents")
          a.remove_file!
          a.save!
        end

        expect(a.file_thumb?).to be_truthy
        expect(a.file_thumb.read).to eq "replaced contents"
        expect(a.file?).to be_falsey
      end

      it "does not remove follower if it has been changed before destruction outside a transaction" do
        a = klass.create! file: StringIO.new("some contents without a filename")
        expect(a.file_thumb.read).to eq "some contents without a filename"

        a.file_thumb = StringIO.new("replaced contents")
        a.remove_file!
        a.save!

        expect(a.file_thumb?).to be_truthy
        expect(a.file_thumb.read).to eq "replaced contents"
        expect(a.file?).to be_falsey
      end
    end

    context "with dependent: :ignore" do
      let(:klass) {
        a = Class.new(Test) { include Saviour::Model }
        a.attach_file :file, uploader
        a.attach_file :file_thumb, uploader_for_version, follow: :file, dependent: :ignore
        a
      }

      it "leaves followers" do
        a = klass.create! file: StringIO.new("some contents without a filename")
        expect(a.file_thumb.read).to eq "some contents without a filename"

        a.remove_file!
        expect(a.file_thumb?).to be_truthy
        expect(a.file_thumb.read).to eq "some contents without a filename"
        expect(a.file.read).to be_nil
      end
    end
  end
end