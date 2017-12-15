require 'spec_helper'

describe "dirty model" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  it "provides changes and previous file" do
    uploader = Class.new(Saviour::BaseUploader) { store_dir { "/store/dir" } }
    klass = Class.new(Test) { include Saviour::Model }
    klass.attach_file :file, uploader
    a = klass.create!

    with_test_file("example.xml") do |xml_file|
      with_test_file("camaloon.jpg") do |jpg_file|
        a.update_attributes! file: xml_file

        expect(a.changed_attributes).to eq({})

        expect(a.file.exists?).to be_truthy
        expect(a.file_changed?).to be_falsey
        expect(a.file.persisted?).to be_truthy

        a.file = jpg_file
        expect(a.file.persisted?).to be_falsey

        expect(a.file_changed?).to be_truthy
        expect(a.file_was).to_not eq(a.file)
        expect(a.file_was.url).to match /\.xml$/
        expect(a.file_was.persisted?).to be_truthy

        expect(a.changed_attributes).to include("file" => a.file_was)
      end
    end
  end

  it "changes are nil when not persisted" do
    uploader = Class.new(Saviour::BaseUploader) { store_dir { "/store/dir" } }
    klass = Class.new(Test) { include Saviour::Model }
    klass.attach_file :file, uploader

    a = klass.new file: Saviour::StringSource.new("contents", "file.txt")
    expect(a.file_changed?).to be_truthy
    expect(a.file_was).to be_nil
  end
end
