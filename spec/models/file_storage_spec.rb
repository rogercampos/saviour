require 'spec_helper'

describe Saviour::FileStorage do
  describe "#write" do
    let(:filename) { "output.jpg" }
    let(:destination_path) { File.join(@tmpdir, filename) }

    it "writting a new file" do
      with_test_file("camaloon.jpg") do |file, _|
        expect(File.file?(destination_path)).to be_falsey

        contents = file.read
        subject.write(contents, destination_path)

        expect(File.file?(destination_path)).to be_truthy
        expect(File.read(destination_path)).to eq contents
      end
    end

    it "overwritting an existing file" do
      File.write(destination_path, "some dummy content")
      expect(File.file?(destination_path)).to be_truthy

      with_test_file("camaloon.jpg") do |file, _|
        contents = file.read
        subject.write(contents, destination_path)

        expect(File.file?(destination_path)).to be_truthy
        expect(File.read(destination_path)).to eq contents
      end
    end
  end

  describe "#read" do
    it "reads an existing file" do
      with_test_file("camaloon.jpg") do |file, _|
        expect(subject.read(file.path)).to eq file.read
      end
    end

    it "fails if the file do not exists" do
      expect { subject.read(File.join(@tmpdir, "nope.rar")) }.to raise_error
    end
  end

  describe "#delete" do
    it "deletes an existing file" do
      with_test_file("camaloon.jpg") do |file, _|
        expect(File.file?(file.path)).to be_truthy

        subject.delete(file.path)
        expect(File.file?(file.path)).to be_falsey
      end
    end

    it "fails if the file do not exists" do
      expect { subject.delete(File.join(@tmpdir, "nope.rar")) }.to raise_error
    end
  end

  describe "#exists?" do
    it "with existing file" do
      with_test_file("camaloon.jpg") do |file, _|
        expect(subject.exists?(file.path)).to be_truthy
      end
    end

    it "with no file" do
      expect(subject.exists?(File.join(@tmpdir, "unexisting_file.zip"))).to be_falsey
    end
  end
end