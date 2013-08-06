require 'spec_helper'

describe "saving a new file" do
  before { Saviour::Config.storage = Saviour::FileStorage.new(local_prefix: @tmpdir, public_uri_prefix: "http://domain.com") }
  after { Saviour::Config.storage = nil }

  class A < Test
    class TestUploader < Saviour::BaseUploader
      def store_dir
        "/store/dir"
      end
    end

    include Saviour
    attach_file :file, TestUploader
  end

  describe "creation" do
    it do
      with_test_file("example.xml") do |example|
        a = A.create!
        expect(a.update_attributes(file: example)).to be_truthy
      end
    end

    it do
      with_test_file("example.xml") do |example|
        a = A.create!
        a.update_attributes(file: example)

        expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy
      end
    end

    it do
      with_test_file("example.xml") do |example, real_filename|
        a = A.create!
        a.update_attributes(file: example)
        expect(a[:file]).to eq "/store/dir/#{real_filename}"
      end
    end

    it do
      with_test_file("example.xml") do |example|
        a = A.create!
        a.update_attributes(file: example)

        example.rewind
        expect(a.file.read).to eq example.read
      end
    end

    it do
      with_test_file("example.xml") do |example|
        a = A.create!
        a.update_attributes(file: example)

        expect(a.file.exists?).to be_truthy
      end
    end

    it do
      with_test_file("example.xml") do |example, real_filename|
        a = A.create!
        a.update_attributes(file: example)

        expect(a.file.filename).to eq real_filename
      end
    end

    it do
      with_test_file("example.xml") do |example, real_filename|
        a = A.create!
        a.update_attributes(file: example)

        expect(a.file.url).to eq "http://domain.com/store/dir/#{real_filename}"
        expect(a.file.public_uri).to eq a.file.url
      end
    end
  end

  describe "deletion" do
    it do
      with_test_file("example.xml") do |example|
        a = A.create!
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
        a = A.create!
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
  end
end