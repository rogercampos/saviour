require 'spec_helper'

describe "dirty model" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  before do
    uploader = Class.new(Saviour::BaseUploader) { store_dir { "/store/dir" } }
    @klass = Class.new(Test) { include Saviour::Model }
    @klass.attach_file :file, uploader
  end

  it "provides changes and previous file" do
    a = @klass.create!

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
        expect(a.changed).to eq ["file"]

        expect(a.changed?).to be_truthy

        expect(a.changes).to eq({"file" => [a.file_was, a.file]})
      end
    end
  end

  it "provides changes on two changed attributes" do
    a = @klass.create!

    a.name = "Foo bar"
    a.file = Saviour::StringSource.new("contents", "file.txt")

    expect(a.changed.sort).to eq ["file", "name"]
    a.save!

    a.name = "Johny"
    a.file = Saviour::StringSource.new("contents", "file_2.txt")

    expect(a.changed.sort).to eq ["file", "name"]
    expect(a.changes).to eq({ "file" => [a.file_was, a.file], "name" => ["Foo bar", "Johny"]})
  end

  it "returns always the first ever known value as was" do
    a = @klass.create! file: Saviour::StringSource.new("contents", "file.txt")
    url_was = a.file.url

    a.file = Saviour::StringSource.new("contents", "file_45.txt")
    expect(a.file_was.url).to eq url_was

    a.file = Saviour::StringSource.new("contents", "file_95.txt")
    expect(a.file_was.url).to eq url_was
  end

  it "changes are nil when not persisted" do
    a = @klass.new file: Saviour::StringSource.new("contents", "file.txt")

    expect(a.file_changed?).to be_truthy
    expect(a.file_was).to be_nil
  end

  it "changes are nil when persisted but no file was assigned" do
    a = @klass.create!
    a.file = Saviour::StringSource.new("contents", "file.txt")
    expect(a.file_was).to be_nil
  end

  it "was data is kept after reload" do
    a = @klass.create! file: Saviour::StringSource.new("contents", "file.txt"), name: "Cuca"
    expect(a.name_was).to eq "Cuca"
    expect(a.file_was).to eq a.file

    a.reload
    expect(a.file_was).to eq a.file
  end

  it "was data is refreshed on persisting a new assignation" do
    a = @klass.create! file: Saviour::StringSource.new("contents", "file.txt")
    a.file = Saviour::StringSource.new("contents", "file_2.txt")
    a.save!
    expect(a.file_was.url).to match(/file_2\.txt/)
  end

  it "was file is cleared on dup" do
    a = @klass.create! file: Saviour::StringSource.new("contents", "file.txt")
    expect(a.file_was).to eq a.file

    b = a.dup
    expect(b.file_was).to be_nil
  end
end
