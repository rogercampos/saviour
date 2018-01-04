require 'spec_helper'

describe Saviour::BaseUploader do
  describe "DSL" do
    subject { Class.new(Saviour::BaseUploader) }

    it do
      subject.process :hola
      expect(subject.processors[0][:method_or_block]).to eq :hola
      expect(subject.processors[0][:opts]).to eq({})
    end

    it do
      subject.process :a
      subject.process :resize, width: 50

      expect(subject.processors[0][:method_or_block]).to eq :a
      expect(subject.processors[0][:opts]).to eq({})

      expect(subject.processors[1][:method_or_block]).to eq :resize
      expect(subject.processors[1][:opts]).to eq({ width: 50 })
    end

    it do
      subject.process { 5 }
      expect(subject.processors[0][:method_or_block]).to respond_to :call
      expect(subject.processors[0][:method_or_block].call).to eq 5
    end

    it do
      subject.store_dir { "/my/dir" }
      expect(subject.store_dirs[0].call).to eq "/my/dir"
    end

    it do
      subject.store_dir :method_to_return_the_dir
      expect(subject.store_dirs[0]).to eq :method_to_return_the_dir
    end

    it "can use store_dir twice and last prevails" do
      subject.store_dir { "/my/dir" }
      subject.store_dir { "/my/dir/4" }
      expect(subject.store_dirs[0].call).to eq "/my/dir"
      expect(subject.store_dirs[1].call).to eq "/my/dir/4"
    end

    it "is not accessible from subclasses, works in isolation" do
      subject.process :hola
      expect(subject.processors[0][:method_or_block]).to eq :hola
      expect(subject.processors[0][:opts]).to eq({})

      subclass = Class.new(subject)
      expect(subclass.processors).to eq []
    end
  end

  describe "initialization with data" do
    it "can declare wathever" do
      uploader = Class.new(Saviour::BaseUploader).new(data: { a: "2", data: "my file" })
      expect(uploader).to respond_to :a
      expect(uploader).to respond_to :data
      expect(uploader.a).to eq "2"
    end

    it do
      uploader = Class.new(Saviour::BaseUploader).new(data: { a: "2", data: "my file" })
      expect(uploader).to respond_to :a

      uploader = Class.new(Saviour::BaseUploader).new(data: { name: "johny" })
      expect(uploader).not_to respond_to :a
    end
  end

  describe "#_process_as_contents" do
    subject { uploader.new(data: { model: "model", attached_as: "attached_as" }) }

    context do
      let(:uploader) { Class.new(Saviour::BaseUploader) }

      it "error if no store_dir" do
        expect { subject._process_as_contents("contents", "filename.jpg") }.to raise_error(Saviour::ConfigurationError)
      end
    end

    context do
      let(:uploader) { Class.new(Saviour::BaseUploader) {
        store_dir { "/store/dir" }
      } }

      it "returns the final contents and fullpath" do
        expect(subject._process_as_contents("contents", "file.jpg")).to eq ["contents", '/store/dir/file.jpg']
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
        expect(subject._process_as_contents("content", "output.png")).to eq ["content-x2", "/store/dir/output.png"]
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
        expect(subject._process_as_contents("content", "output.png")).to eq ["content-x2_x9", "/store/dir/prefix-output.png"]
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
        expect(subject._process_as_contents("content", "output.png")).to eq ["content-50-10", "/store/dir/output.png"]
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
      subject { uploader.new(data: { model: model, attached_as: "attached_as" }) }

      it "can access model from processors" do
        expect(subject._process_as_contents("content", "output.png")).to eq ["content", "/store/dir/Robert_8_output.png"]
      end
    end

    describe "returns nil if halted" do
      let(:uploader) { Class.new(Saviour::BaseUploader) {
        store_dir { "/store/dir" }
        process { halt_process }
      } }

      it do
        expect(Saviour::Config.storage).to_not receive(:_process_as_contents)
        expect(subject._process_as_contents("contents", "file.jpg")).to be_nil
      end
    end
  end

  describe "#process_with_file" do
    subject { uploader.new(data: { model: "model", attached_as: "attached_as" }) }

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
        expect(subject._process_as_contents("contents", "output.png")).to eq ["modified-contents", "/store/dir/output.png"]
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
        expect(subject._process_as_contents("contents", "aaa.png")).to eq ["pre-contents_first_run-modified-contents", "/store/dir/pre-aaa.png"]
      end
    end
  end
end
