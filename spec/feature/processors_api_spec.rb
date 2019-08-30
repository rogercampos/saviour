require 'spec_helper'

describe "processor's API" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  let(:uploader) {
    Class.new(Saviour::BaseUploader) do
      store_dir { "/store/dir/#{model.value}" }
      process { |contents, name| [contents, "#{model.value}-#{attached_as}-#{name}"] }
    end
  }

  let(:klass) {
    klass = Class.new(Test) {
      include Saviour::Model

      def value
        87
      end
    }
    klass.attach_file :file, uploader
    klass
  }

  describe "can access to model and attached_as" do
    it do
      with_test_file("example.xml") do |example, name|
        a = klass.new
        a.file = example
        path = a.file.write

        expect(Saviour::Config.storage.exists?(path)).to be_truthy
        expect(path).to eq "/store/dir/87/87-file-#{name}"
      end
    end
  end

  describe "can access store_dir" do
    let(:uploader) {
      Class.new(Saviour::BaseUploader) do
        store_dir { "/store/dir/#{model.value}" }
        process { |_, name| ["FAKE: #{store_dir}", name] }
      end
    }

    it do
      with_test_file("example.xml") do |example, name|
        a = klass.new
        a.file = example
        path = a.file.write

        contents = Saviour::Config.storage.read(path)
        expect(Saviour::Config.storage.exists?(path)).to be_truthy
        expect(contents).to eq "FAKE: /store/dir/87"
      end
    end
  end

  describe "can access id on the model (after_create)" do
    let(:uploader) {
      Class.new(Saviour::BaseUploader) do
        store_dir { "/store/dir/#{model.id}" }
      end
    }

    it do
      with_test_file("example.xml") do |example, name|
        a = klass.create! file: example

        expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy
        expect(a[:file]).to eq "/store/dir/#{a.id}/#{name}"
      end
    end
  end

  describe "errors raised from processors are propagated" do
    let(:uploader) {
      Class.new(Saviour::BaseUploader) do
        store_dir { "/store/dir/#{model.id}" }

        process do |contents, filename|
          raise "custom problem!"
        end
      end
    }

    it "on update" do
      a = klass.create!

      expect {
        a.update! file: Saviour::StringSource.new("contents", "filename.txt")
      }.to raise_error.with_message("custom problem!")
    end

    it "on create" do
      expect {
        klass.create! file: Saviour::StringSource.new("contents", "filename.txt")
      }.to raise_error.with_message("custom problem!")
    end
  end
end
