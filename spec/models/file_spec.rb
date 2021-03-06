require 'spec_helper'

describe Saviour::File do
  class ComparableStringIO < StringIO
    def ==(a)
      a.is_a?(ComparableStringIO) && a.read == read
    end
  end

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
    store_dir { "/store/dir" }
  } }

  let(:example_file) { double(read: "some file contents", filename: "file.txt", rewind: nil) }

  let(:dummy_class) {
    klass = Class.new
    Saviour::Integrator.new(klass, Saviour::PersistenceLayer).setup!
    klass
  }

  describe "#assign" do
    it "returns the assigned object" do
      file = Saviour::File.new(uploader_klass, dummy_class.new, :file)
      expect(file.assign(example_file)).to eq example_file
    end

    it "allows to reset the internal source" do
      file = Saviour::File.new(uploader_klass, dummy_class.new, :file)
      file.assign(example_file)
      expect(file.assign(nil)).to be_nil
    end

    it "shows error if assigned object do not respond to :read" do
      file = Saviour::File.new(uploader_klass, dummy_class.new, :file)
      expect { file.assign(6) }.to raise_error(Saviour::SourceError)
    end
  end

  describe "#write" do
    it "fails without source" do
      file = Saviour::File.new(uploader_klass, dummy_class.new, :file)
      expect { file.write }.to raise_error(Saviour::MissingSource)
    end

    describe "filename used" do
      it "is extracted from original_filename if possible" do
        file = Saviour::File.new(uploader_klass, dummy_class.new, :file)
        file.assign(double(read: "contents", original_filename: 'original.jpg', rewind: nil))
        uploader = double
        allow(file).to receive(:uploader).and_return(uploader)
        expect(uploader).to receive(:_process_as_contents).with("contents", "original.jpg")
        file.write
      end

      it "is extracted from path if possible" do
        file = Saviour::File.new(uploader_klass, dummy_class.new, :file)
        with_test_file("example.xml") do |xml_file|
          dummy_file = double(read: "contents", path: xml_file.path, rewind: nil)
          file.assign(dummy_file)
          uploader = double
          allow(file).to receive(:uploader).and_return(uploader)
          expect(uploader).to receive(:_process_as_file).with(an_instance_of(Tempfile), File.basename(xml_file.path))
          file.write
        end
      end

      it "is random if cannot be guessed" do
        file = Saviour::File.new(uploader_klass, dummy_class.new, :file)
        file.assign(double(read: "contents", rewind: nil))
        allow(SecureRandom).to receive(:hex).and_return("stubbed-random")
        uploader = double
        allow(file).to receive(:uploader).and_return(uploader)
        expect(uploader).to receive(:_process_as_contents).with("contents", "stubbed-random")
        file.write
      end
    end

    it "returns the final contents and path" do
      object = dummy_class.new
      file = Saviour::File.new(uploader_klass, object, :file)
      file.assign(double(read: "contents", filename: "my_file.zip", rewind: nil))
      uploader = double
      allow(file).to receive(:uploader).and_return(uploader)
      expect(uploader).to receive(:_process_as_contents).with("contents", "my_file.zip").and_return(['contents', "/store/dir/my_file.zip"])
      expect(file.write).to eq "/store/dir/my_file.zip"
    end
  end

  describe "#changed?" do
    it "is cleared after removing the assignation" do
      file = Saviour::File.new(uploader_klass, dummy_class.new, :file)
      expect(file).not_to be_changed
      file.assign(example_file)
      expect(file).to be_changed
      file.assign(nil)
      expect(file).not_to be_changed
    end

    it "is cleared after persisting" do
      file = Saviour::File.new(uploader_klass, dummy_class.new, :file)
      file.assign(double(read: "contents", filename: "my_file.zip", rewind: nil))
      expect(file).to be_changed

      uploader = double
      allow(file).to receive(:uploader).and_return(uploader)
      expect(uploader).to receive(:_process_as_contents).and_return("/some/path")
      file.write

      expect(file).not_to be_changed
    end
  end

  describe "#filename" do
    it "returns the filename of the persisted file" do
      file = Saviour::File.new(uploader_klass, dummy_class.new, :file, "/mocked/path/file.rar")
      expect(file.filename).to eq "file.rar"
    end

    it "returns nil if the file doesn't exist" do
      file = Saviour::File.new(uploader_klass, dummy_class.new, :file)
      expect(file.filename).to be_nil
    end
  end

  describe "#blank?" do
    it "it's true when not yet assigned nor persisted" do
      file = Saviour::File.new(uploader_klass, dummy_class.new, :file)
      expect(file).to be_blank
    end

    it "it's false when not yet assigned but persisted" do
      file = Saviour::File.new(uploader_klass, dummy_class.new, :file, "/path/dummy.jpg")
      expect(file).not_to be_blank
    end

    it "it's false when not persisted but assigned" do
      file = Saviour::File.new(uploader_klass, dummy_class.new, :file)
      file.assign example_file
      expect(file).not_to be_blank
    end

    it "it's false when persisted and assigned" do
      file = Saviour::File.new(uploader_klass, dummy_class.new, :file, "/path/dummy.jpg")
      expect(file).not_to be_blank
    end
  end

  describe "#clone" do
    it "returns a cloned instance pointing to the same stored file" do
      file = Saviour::File.new(uploader_klass, dummy_class.new, :file, "/path/dummy.jpg")

      new_file = file.clone
      expect(new_file.persisted_path).to eq "/path/dummy.jpg"
    end
  end

  describe "#==" do
    it "compares by object persisted path if persisted" do
      a = Saviour::File.new(uploader_klass, dummy_class.new, :file, "/path/dummy.jpg")
      b = Saviour::File.new(uploader_klass, dummy_class.new, :file, "/path/dummy.jpg")

      expect(a).to eq b
    end

    it "compares by content if not persisted" do
      a = Saviour::File.new(uploader_klass, dummy_class.new, :file)
      a.assign(ComparableStringIO.new("content"))

      b = Saviour::File.new(uploader_klass, dummy_class.new, :file)
      b.assign(ComparableStringIO.new("content"))

      expect(a).to eq b

      b.assign(ComparableStringIO.new("another content"))
      expect(a).to_not eq b
    end
  end

  describe "#read" do
    it "returns nil when there's no file persisted" do
      a = Saviour::File.new(uploader_klass, dummy_class.new, :file)
      expect(a.read).to be_nil
    end
  end

  describe "#public_url" do
    it "returns nil when there's no file persisted" do
      a = Saviour::File.new(uploader_klass, dummy_class.new, :file)
      expect(a.public_url).to be_nil
    end
  end
end
