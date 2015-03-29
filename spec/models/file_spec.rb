require 'spec_helper'

describe Saviour::File do
  let(:mocked_storage) {
    Class.new {
      def write(content, filename)
      end

      def read(path)
      end

      def delete(path)
      end

      def exists?(path)
      end
    }.new
  }

  before { allow(Saviour::Config).to receive(:storage).and_return(mocked_storage) }

  let(:uploader_klass) { Class.new(Saviour::BaseUploader) {
    def store_dir
      "/store/dir"
    end
  } }

  let(:example_file) { double(read: "some file contents", path: "/my/path") }

  describe "initialization" do
    describe "derives persisted from the model" do
      it do
        file = Saviour::File.new(uploader_klass, Test.new, :file)
        expect(file).not_to be_persisted
      end

      it do
        file = Saviour::File.new(uploader_klass, Test.create!, :file)
        expect(file).not_to be_persisted
      end

      it do
        file = Saviour::File.new(uploader_klass, Test.create!(file: "/mocked/path"), :file)
        expect(file).to be_persisted
      end
    end

    describe "is not changed" do
      it do
        file = Saviour::File.new(uploader_klass, Test.new, :file)
        expect(file).not_to be_changed
      end

      it do
        file = Saviour::File.new(uploader_klass, Test.create!, :file)
        expect(file).not_to be_changed
      end

      it do
        file = Saviour::File.new(uploader_klass, Test.create!(file: "/mocked/path"), :file)
        expect(file).not_to be_changed
      end
    end
  end

  describe "#assign" do
    it "returns the assigned object" do
      file = Saviour::File.new(uploader_klass, Test.new, :file)
      expect(file.assign(example_file)).to eq example_file
    end

    it "allows to reset the internal source" do
      file = Saviour::File.new(uploader_klass, Test.new, :file)
      file.assign(example_file)
      expect(file.assign(nil)).to be_nil
    end

    it "shows error if assigned object do not respond to :read" do
      file = Saviour::File.new(uploader_klass, Test.new, :file)
      expect { file.assign(6) }.to raise_error
    end
  end

  describe "#write" do
    it "fails without source" do
      file = Saviour::File.new(uploader_klass, Test.new, :file)
      expect { file.write }.to raise_error
    end

    describe "filename used" do
      it "is extracted from original_filename if possible" do
        file = Saviour::File.new(uploader_klass, Test.new, :file)
        file.assign(double(read: "contents", original_filename: 'original.jpg', path: "/my/path/my_file.zip"))
        uploader = double
        allow(file).to receive(:uploader).and_return(uploader)
        expect(uploader).to receive(:write).with("contents", "original.jpg")
        file.write
      end

      it "is extracted from path if possible" do
        file = Saviour::File.new(uploader_klass, Test.new, :file)
        file.assign(double(read: "contents", path: "/my/path/my_file.zip"))
        uploader = double
        allow(file).to receive(:uploader).and_return(uploader)
        expect(uploader).to receive(:write).with("contents", "my_file.zip")
        file.write
      end

      it "is random if cannot be guessed" do
        file = Saviour::File.new(uploader_klass, Test.new, :file)
        file.assign(double(read: "contents"))
        allow(SecureRandom).to receive(:hex).and_return("stubbed-random")
        uploader = double
        allow(file).to receive(:uploader).and_return(uploader)
        expect(uploader).to receive(:write).with("contents", "stubbed-random")
        file.write
      end
    end

    it "returns the path" do
      object = Test.new
      file = Saviour::File.new(uploader_klass, object, :file)
      file.assign(double(read: "contents", path: "/my/path/my_file.zip"))
      uploader = double
      allow(file).to receive(:uploader).and_return(uploader)
      expect(uploader).to receive(:write).with("contents", "my_file.zip").and_return("/store/dir/my_file.zip")
      expect(file.write).to eq "/store/dir/my_file.zip"
    end
  end

  describe "#changed?" do
    it "is cleared after removing the assignation" do
      file = Saviour::File.new(uploader_klass, Test.new, :file)
      expect(file).not_to be_changed
      file.assign(example_file)
      expect(file).to be_changed
      file.assign(nil)
      expect(file).not_to be_changed
    end

    it "is cleared after persisting" do
      file = Saviour::File.new(uploader_klass, Test.new, :file)
      file.assign(double(read: "contents", path: "/my/path/my_file.zip"))
      expect(file).to be_changed

      uploader = double
      allow(file).to receive(:uploader).and_return(uploader)
      expect(uploader).to receive(:write)
      file.write

      expect(file).not_to be_changed
    end
  end

  describe "#filename" do
    it "returns the filename of the persisted file" do
      file = Saviour::File.new(uploader_klass, Test.create!(file: "/mocked/path/file.rar"), :file)
      expect(file.filename).to eq "file.rar"
    end
  end

  describe "#with_copy" do
    it "provides a copy of the stored file" do
      file = Saviour::File.new(uploader_klass, Test.create!(file: "/mocked/path/file.rar"), :file)
      allow(file).to receive(:read).and_return("some contents")

      file.with_copy do |tmpfile|
        expect(tmpfile.read).to eq "some contents"
      end
    end

    it "deletes the copied file even on exception" do
      file = Saviour::File.new(uploader_klass, Test.create!(file: "/mocked/path/file.rar"), :file)
      allow(file).to receive(:read).and_return("some contents")
      mocked_tmpfile = double(binmode: "", rewind: "", flush: "", write: "")
      allow(Tempfile).to receive(:open).and_yield(mocked_tmpfile)

      expect(mocked_tmpfile).to receive(:close)
      expect(mocked_tmpfile).to receive(:delete)

      test_exception = Class.new(Exception)

      begin
        file.with_copy {|_| raise(test_exception, "some exception within the block") }
      rescue test_exception
      end
    end
  end
end
