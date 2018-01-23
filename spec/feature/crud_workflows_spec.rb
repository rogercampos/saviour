require 'spec_helper'

describe "saving a new file" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  let(:uploader) {
    Class.new(Saviour::BaseUploader) {
      store_dir { "/store/dir" }
    }
  }

  let(:klass) {
    a = Class.new(Test) { include Saviour::Model }
    a.attach_file :file, uploader
    a
  }

  describe "creation" do
    it do
      with_test_file("example.xml") do |example|
        a = klass.create!
        expect(a.update_attributes(file: example)).to be_truthy
      end
    end

    it do
      with_test_file("example.xml") do |example|
        a = klass.create!
        a.update_attributes(file: example)

        expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy
      end
    end

    it do
      with_test_file("example.xml") do |example, real_filename|
        a = klass.create!
        a.update_attributes(file: example)
        expect(a[:file]).to eq "/store/dir/#{real_filename}"
      end
    end

    it do
      with_test_file("example.xml") do |example|
        a = klass.create!
        a.update_attributes(file: example)

        example.rewind
        expect(a.file.read).to eq example.read
      end
    end

    it do
      with_test_file("example.xml") do |example|
        a = klass.create!
        a.update_attributes(file: example)

        expect(a.file.exists?).to be_truthy
      end
    end

    it do
      with_test_file("example.xml") do |example, real_filename|
        a = klass.create!
        a.update_attributes(file: example)

        expect(a.file.filename).to eq real_filename
      end
    end

    it do
      with_test_file("example.xml") do |example, real_filename|
        a = klass.create!
        a.update_attributes(file: example)

        expect(a.file.url).to eq "http://domain.com/store/dir/#{real_filename}"
        expect(a.file.public_url).to eq a.file.url
      end
    end

    it "don't create anything if save do not completes (halt during before_save)" do
      klass = Class.new(Test) do
        attr_accessor :fail_at_save
        before_save {
          throw(:abort) if fail_at_save
        }
        include Saviour::Model
      end
      klass.attach_file :file, uploader

      expect {
        a = klass.new
        a.fail_at_save = true
        a.save!
      }.to raise_error(ActiveRecord::RecordNotSaved)

      with_test_file("example.xml") do |example, _|
        a = klass.new
        a.fail_at_save = true
        a.file = example

        expect(Saviour::Config.storage).not_to receive(:write)
        a.save
      end
    end
  end

  describe "deletion" do
    it do
      with_test_file("example.xml") do |example|
        a = klass.create!
        a.update_attributes(file: example)
        expect(a.file.exists?).to be_truthy
        expect(a.destroy).to be_truthy

        expect(Saviour::Config.storage.exists?(a[:file])).to be_falsey
      end
    end
  end

  describe "updating" do
    it do
      with_test_file("example.xml") do |example|
        a = klass.create!
        a.update_attributes(file: example)

        expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy
        previous_location = a[:file]

        with_test_file("camaloon.jpg") do |example_2|
          a.update_attributes(file: example_2)
          expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy

          expect(Saviour::Config.storage.exists?(previous_location)).to be_falsey
        end
      end
    end

    it "does allow to update the same file to another contents in the same path" do
      a = klass.create! file: Saviour::StringSource.new("contents", "file.txt")

      a.update_attributes! file: Saviour::StringSource.new("foo", "file.txt")
      expect(Saviour::Config.storage.read(a[:file])).to eq "foo"
    end
  end

  describe "dupping" do
    let(:uploader) {
      Class.new(Saviour::BaseUploader) {
        store_dir { "/store/dir/#{model.id}" }
      }
    }

    it "creates a non persisted file attachment" do
      a = klass.create! file: Saviour::StringSource.new("contents", "file.txt")
      expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy

      b = a.dup
      expect(b).to_not be_persisted
      expect(b.file).to_not be_persisted
    end

    it "can be saved" do
      a = klass.create! file: Saviour::StringSource.new("contents", "file.txt")
      b = a.dup
      b.save!

      expect(Saviour::Config.storage.exists?(b[:file])).to be_truthy
      expect(Saviour::Config.storage.read(a[:file])).to eq Saviour::Config.storage.read(b[:file])
    end
  end
end
