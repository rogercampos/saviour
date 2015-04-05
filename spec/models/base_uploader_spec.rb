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
      subject.run :hola
      expect(subject.processors).to eq [[:hola, {}]]
    end

    it do
      subject.run :a
      subject.run :resize, width: 50
      expect(subject.processors).to eq [[:a, {}], [:resize, {width: 50}]]
    end

    it do
      subject.run { 5 }
      expect(subject.processors.first).to respond_to :call
      expect(subject.processors.first.call).to eq 5
    end

    it do
      subject.store_dir! { "/my/dir" }
      expect(subject.store_dir.call).to eq "/my/dir"
    end

    it do
      subject.store_dir! :method_to_return_the_dir
      expect(subject.store_dir).to eq :method_to_return_the_dir
    end

    it "can use store_dir twice and last prevails" do
      subject.store_dir! { "/my/dir" }
      subject.store_dir! { "/my/dir/4" }
      expect(subject.store_dir.call).to eq "/my/dir/4"
    end
  end

  describe "#write" do
    subject { uploader.new(model: "model", mounted_as: "mounted_as") }

    context do
      let(:uploader) { Class.new(Saviour::BaseUploader) }

      it "error if no store_dir" do
        expect { subject.write("contents", "filename.jpg") }.to raise_error
      end
    end

    context do
      let(:uploader) { Class.new(Saviour::BaseUploader) {
        store_dir! { "/store/dir" }
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
        store_dir! { "/store/dir" }

        def resize(contents, filename)
          ["#{contents}-x2", filename]
        end

        run :resize
      } }

      it "calls the processors" do
        expect(subject).to receive(:resize).with("content", "output.png").and_call_original
        expect(Saviour::Config.storage).to receive(:write).with("content-x2", "/store/dir/output.png")
        subject.write("content", "output.png")
      end
    end

    context do
      let(:uploader) { Class.new(Saviour::BaseUploader) {
        store_dir! { "/store/dir" }

        def resize(contents, filename)
          ["#{contents}-x2", filename]
        end

        run :resize
        run { |content, filename| ["#{content}_x9", "prefix-#{filename}"] }
      } }

      it "respects ordering on processor calling" do
        expect(Saviour::Config.storage).to receive(:write).with("content-x2_x9", "/store/dir/prefix-output.png")
        subject.write("content", "output.png")
      end
    end

    context do
      let(:uploader) { Class.new(Saviour::BaseUploader) {
        store_dir! { "/store/dir" }

        def resize(contents, filename, opts = {})
          ["#{contents}-#{opts[:width]}-#{opts[:height]}", filename]
        end

        run :resize, width: 50, height: 10
      } }

      it "calls the method using the stored arguments" do
        expect(Saviour::Config.storage).to receive(:write).with("content-50-10", "/store/dir/output.png")
        subject.write("content", "output.png")
      end
    end

    context do
      let(:uploader) { Class.new(Saviour::BaseUploader) {
        store_dir! { "/store/dir" }

        def rename(contents, filename)
          [contents, "#{model.id}_#{filename}"]
        end

        run :rename
        run { |content, filename| [content, "#{model.name}_#{filename}"] }
      } }

      let(:model) { double(id: 8, name: "Robert") }
      subject { uploader.new(model: model, mounted_as: "mounted_as") }

      it "can access model from processors" do
        expect(Saviour::Config.storage).to receive(:write).with("content", "/store/dir/Robert_8_output.png")
        subject.write("content", "output.png")
      end
    end
  end
end
