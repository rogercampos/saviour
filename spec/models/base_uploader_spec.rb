require 'spec_helper'

describe Saviour::BaseUploader do
  let(:mocked_storage) {
    Class.new {
      def write(content, filename)
        # pass
      end
    }.new
  }
  before { allow(Saviour::Config).to receive(:storage).and_return(mocked_storage) }


  describe "DSL" do
    subject { Class.new(Saviour::BaseUploader) }

    it do
      subject.process :hola
      expect(subject.processors[0][:element].method_or_block).to eq :hola
      expect(subject.processors[0][:opts]).to eq({})
    end

    it do
      subject.process :a
      subject.process :resize, width: 50

      expect(subject.processors[0][:element].method_or_block).to eq :a
      expect(subject.processors[0][:opts]).to eq({})

      expect(subject.processors[1][:element].method_or_block).to eq :resize
      expect(subject.processors[1][:opts]).to eq({width: 50})
    end

    it do
      subject.process { 5 }
      expect(subject.processors[0][:element].method_or_block).to respond_to :call
      expect(subject.processors[0][:element].method_or_block.call).to eq 5
    end

    it do
      subject.store_dir { "/my/dir" }
      expect(subject.store_dirs[0].method_or_block.call).to eq "/my/dir"
    end

    it do
      subject.store_dir :method_to_return_the_dir
      expect(subject.store_dirs[0].method_or_block).to eq :method_to_return_the_dir
    end

    it "can use store_dir twice and last prevails" do
      subject.store_dir { "/my/dir" }
      subject.store_dir { "/my/dir/4" }
      expect(subject.store_dirs[0].method_or_block.call).to eq "/my/dir"
      expect(subject.store_dirs[1].method_or_block.call).to eq "/my/dir/4"
    end

    it "is not accessible from subclasses, works in isolation" do
      subject.process :hola
      expect(subject.processors[0][:element].method_or_block).to eq :hola
      expect(subject.processors[0][:opts]).to eq({})

      subclass = Class.new(subject)
      expect(subclass.processors).to eq []
    end

    describe "version" do
      it "stores as elements with the given version" do
        subject.process :hola
        subject.version(:thumb) do
          process :resize_to_thumb
        end

        expect(subject.processors[0][:element].method_or_block).to eq :hola
        expect(subject.processors[0][:element].version).to eq nil
        expect(subject.processors[0][:opts]).to eq({})

        expect(subject.processors[1][:element].method_or_block).to eq :resize_to_thumb
        expect(subject.processors[1][:element].version).to eq :thumb
        expect(subject.processors[1][:opts]).to eq({})
      end

      it "respects ordering" do
        subject.process :hola
        subject.version(:thumb) { process :resize_to_thumb }
        subject.process :top_level
        subject.version(:another) { process(:foo) }

        expect(subject.processors[0][:element].method_or_block).to eq :hola
        expect(subject.processors[0][:element].version).to eq nil
        expect(subject.processors[1][:element].method_or_block).to eq :resize_to_thumb
        expect(subject.processors[1][:element].version).to eq :thumb
        expect(subject.processors[2][:element].method_or_block).to eq :top_level
        expect(subject.processors[2][:element].version).to eq nil
        expect(subject.processors[3][:element].method_or_block).to eq :foo
        expect(subject.processors[3][:element].version).to eq :another
      end
    end
  end

  describe "initialization with data" do
    it "can declare wathever" do
      uploader = Class.new(Saviour::BaseUploader).new(data: {a: "2", data: "my file"})
      expect(uploader).to respond_to :a
      expect(uploader).to respond_to :data
      expect(uploader.a).to eq "2"
    end

    it do
      uploader = Class.new(Saviour::BaseUploader).new(data: {a: "2", data: "my file"})
      expect(uploader).to respond_to :a

      uploader = Class.new(Saviour::BaseUploader).new(data: {name: "johny"})
      expect(uploader).not_to respond_to :a
    end
  end

  describe "#write" do
    subject { uploader.new(data: {model: "model", attached_as: "attached_as"}) }

    context do
      let(:uploader) { Class.new(Saviour::BaseUploader) }

      it "error if no store_dir" do
        expect { subject.write("contents", "filename.jpg") }.to raise_error(RuntimeError)
      end
    end

    context do
      let(:uploader) { Class.new(Saviour::BaseUploader) {
        store_dir { "/store/dir" }
      } }

      it "calls storage write" do
        expect(Saviour::Config.storage).to receive(:write).with("contents", "/store/dir/file.jpg")
        subject.write("contents", "file.jpg")
      end

      it "returns the fullpath" do
        expect(subject.write("contents", "file.jpg")).to eq '/store/dir/file.jpg'
      end
    end

    context do
      let(:uploader) { Class.new(Saviour::BaseUploader) {
        store_dir { "/store/dir" }

        def resize(contents, filename)
          ["#{contents}-x2", filename]
        end

        process :resize
      } }

      it "calls the processors" do
        expect(subject).to receive(:resize).with("content", "output.png").and_call_original
        expect(Saviour::Config.storage).to receive(:write).with("content-x2", "/store/dir/output.png")
        subject.write("content", "output.png")
      end
    end

    context do
      let(:uploader) { Class.new(Saviour::BaseUploader) {
        store_dir { "/store/dir" }

        def resize(contents, filename)
          ["#{contents}-x2", filename]
        end

        process :resize
        process { |content, filename| ["#{content}_x9", "prefix-#{filename}"] }
      } }

      it "respects ordering on processor calling" do
        expect(Saviour::Config.storage).to receive(:write).with("content-x2_x9", "/store/dir/prefix-output.png")
        subject.write("content", "output.png")
      end
    end

    context do
      let(:uploader) { Class.new(Saviour::BaseUploader) {
        store_dir { "/store/dir" }

        def resize(contents, filename, opts = {})
          ["#{contents}-#{opts[:width]}-#{opts[:height]}", filename]
        end

        process :resize, width: 50, height: 10
      } }

      it "calls the method using the stored arguments" do
        expect(Saviour::Config.storage).to receive(:write).with("content-50-10", "/store/dir/output.png")
        subject.write("content", "output.png")
      end
    end

    context do
      let(:uploader) { Class.new(Saviour::BaseUploader) {
        store_dir { "/store/dir" }

        def rename(contents, filename)
          [contents, "#{model.id}_#{filename}"]
        end

        process :rename
        process { |content, filename| [content, "#{model.name}_#{filename}"] }
      } }

      let(:model) { double(id: 8, name: "Robert") }
      subject { uploader.new(data: {model: model, attached_as: "attached_as"}) }

      it "can access model from processors" do
        expect(Saviour::Config.storage).to receive(:write).with("content", "/store/dir/Robert_8_output.png")
        subject.write("content", "output.png")
      end
    end
  end

  describe "version" do
    subject { uploader.new(version: :thumb) }

    describe "store_dir" do
      context "is the last one defined for the given version" do
        let(:uploader) { Class.new(Saviour::BaseUploader) {
          store_dir { "/store/dir" }
          version(:thumb) do
            store_dir { "/thumb/store/dir" }
          end
          store_dir { "/store/dir/second" }
        } }

        it do
          expect(Saviour::Uploader::StoreDirExtractor.new(subject).store_dir).to eq "/thumb/store/dir"
        end
      end

      context "is the last one defined without version if not specified per version" do
        let(:uploader) { Class.new(Saviour::BaseUploader) {
          store_dir { "/store/dir" }
          version(:thumb) { process(:whatever) }
          store_dir { "/store/dir/second" }
        } }

        it do
          expect(Saviour::Uploader::StoreDirExtractor.new(subject).store_dir).to eq "/store/dir/second"
        end
      end

    end

    describe "processing behaviour on write" do
      context "fails if no store_dir defined for root version" do
        let(:uploader) { Class.new(Saviour::BaseUploader) {
          version(:thumb) { store_dir { "/store/dir" } }
        } }

        it do
          a = uploader.new(data: {model: "model", attached_as: "attached_as"})
          expect { a.write('1', '2') }.to raise_error(RuntimeError)
        end
      end

      context "with only one version" do
        let(:uploader) { Class.new(Saviour::BaseUploader) {
          store_dir { "/store/dir" }

          version(:thumb) do
            store_dir { "/versions/store/dir" }
            process { |contents, name| [contents, "2_#{name}"] }
          end
        } }

        it do
          a = uploader.new(version: :thumb)
          expect(Saviour::Config.storage).to receive(:write).with("content", "/versions/store/dir/2_output.png")
          a.write("content", "output.png")
        end

        it do
          a = uploader.new
          expect(Saviour::Config.storage).to receive(:write).with("content", "/store/dir/output.png")
          a.write("content", "output.png")
        end
      end

      context "multiple definitions" do
        let(:uploader) { Class.new(Saviour::BaseUploader) {
          store_dir { "/store/dir" }
          process { |contents, name| ["#{contents}_altered", name] }

          version(:thumb) do
            store_dir { "/versions/store/dir" }
            process { |contents, name| [contents, "2_#{name}"] }
          end
        } }

        it do
          a = uploader.new(version: :thumb)
          expect(Saviour::Config.storage).to receive(:write).with("content_altered", "/versions/store/dir/2_output.png")
          a.write("content", "output.png")
        end

        it do
          a = uploader.new
          expect(Saviour::Config.storage).to receive(:write).with("content_altered", "/store/dir/output.png")
          a.write("content", "output.png")
        end
      end

      context "consecutive versions" do
        let(:uploader) { Class.new(Saviour::BaseUploader) {
          store_dir { "/store/dir" }
          process { |contents, name| ["#{contents}_altered", name] }

          version(:thumb) do
            store_dir { "/versions/store/dir" }
            process { |contents, name| ["thumb_#{contents}", "2_#{name}"] }
          end

          version(:thumb_2) do
            store_dir { "/versions/store/dir" }
            process { |contents, name| ["thumb_2_#{contents}", "3_#{name}"] }
          end

          process { |contents, name| ["last_transform_#{contents}", name] }
        } }

        it do
          a = uploader.new
          expect(Saviour::Config.storage).to receive(:write).with("last_transform_content_altered", "/store/dir/output.png")
          a.write("content", "output.png")
        end

        it do
          a = uploader.new(version: :thumb)
          expect(Saviour::Config.storage).to receive(:write).with("last_transform_thumb_content_altered", "/versions/store/dir/2_output.png")
          a.write("content", "output.png")
        end

        it do
          a = uploader.new(version: :thumb_2)
          expect(Saviour::Config.storage).to receive(:write).with("last_transform_thumb_2_content_altered", "/versions/store/dir/3_output.png")
          a.write("content", "output.png")
        end
      end
    end
  end

  describe "#process_with_file" do
    subject { uploader.new(data: {model: "model", attached_as: "attached_as"}) }

    context do
      let(:uploader) { Class.new(Saviour::BaseUploader) {
        store_dir { "/store/dir" }

        def foo(file, filename)
          ::File.write(file.path, "modified-contents")
          [file, filename]
        end

        process_with_file :foo
      } }

      it "calls the processors" do
        expect(subject).to receive(:foo).with(an_instance_of(Tempfile), "output.png").and_call_original
        expect(Saviour::Config.storage).to receive(:write).with("modified-contents", "/store/dir/output.png")
        subject.write("contents", "output.png")
      end
    end

    context do
      let(:uploader) { Class.new(Saviour::BaseUploader) {
        store_dir { "/store/dir" }

        process do |contents, filename|
          ["#{contents}_first_run", filename]
        end

        process_with_file do |file, filename|
          ::File.write(file.path, "#{::File.read(file.path)}-modified-contents")
          [file, filename]
        end

        process :last_run

        def last_run(contents, filename)
          ["pre-#{contents}", "pre-#{filename}"]
        end
      } }

      it "can mix types of runs between file and contents" do
        expect(Saviour::Config.storage).to receive(:write).with("pre-contents_first_run-modified-contents", "/store/dir/pre-aaa.png")
        subject.write("contents", "aaa.png")
      end
    end
  end
end
