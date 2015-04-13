require 'spec_helper'

describe Saviour::S3Storage do
  subject { Saviour::S3Storage.new(bucket: "fake-bucket", aws_access_key_id: "stub", aws_secret_access_key: "stub") }
  let!(:mocked_s3) { MockedS3Helper.new("fake-bucket") }

  context do
    it "fails when no keys are provided" do
      expect {
        Saviour::S3Storage.new(bucket: "fake-bucket")
      }.to raise_error
    end

    it "fails when the bucket doesn't exists" do
      expect {
        Saviour::S3Storage.new(bucket: "no-bucket", aws_access_key_id: "stub", aws_secret_access_key: "stub")
      }.to raise_error
    end
  end

  describe "#write" do
    let(:destination_path) { "my/folder/file.jpeg" }

    it "writting a new file" do
      with_test_file("camaloon.jpg") do |file, _|
        expect(mocked_s3.exists?(destination_path)).to be_falsey

        contents = file.read
        subject.write(contents, destination_path)

        expect(mocked_s3.read(destination_path)).to eq contents
      end
    end

    it "overwritting an existing file" do
      mocked_s3.write("some dummy contents", destination_path)
      expect(mocked_s3.exists?(destination_path)).to be_truthy

      with_test_file("camaloon.jpg") do |file, _|
        contents = file.read
        subject.write(contents, destination_path)
        expect(mocked_s3.read(destination_path)).to eq contents
      end
    end

    it "ignores leading slash" do
      subject.write("trash contents", "/folder/file.out")
      expect(subject.exists?("folder/file.out")).to be_truthy
      expect(subject.exists?("/folder/file.out")).to be_truthy
      expect(subject.exists?("////folder/file.out")).to be_truthy
    end
  end

  describe "#read" do
    let(:destination_path) { "dest/file.jpeg" }

    it "reads an existing file" do
      with_test_file("camaloon.jpg") do |file, _|
        contents = file.read

        mocked_s3.write(contents, destination_path)
        expect(subject.read(destination_path)).to eq contents
      end
    end

    it "fails if the file do not exists" do
      expect { subject.read("nope.rar") }.to raise_error
    end
  end

  describe "#delete" do
    let(:destination_path) { "dest/file.jpeg" }

    it "deletes an existing file" do
      with_test_file("camaloon.jpg") do |file, _|
        contents = file.read
        mocked_s3.write(contents, destination_path)

        expect(mocked_s3.exists?(destination_path)).to be_truthy
        subject.delete("/dest/file.jpeg")
        expect(mocked_s3.exists?(destination_path)).to be_falsey
      end
    end

    it "fails if the file do not exists" do
      expect { subject.delete("nope.rar") }.to raise_error
    end
  end

  describe "#exists?" do
    let(:destination_path) { "dest/file.jpeg" }

    it "with existing file" do
      with_test_file("camaloon.jpg") do |file, _|
        contents = file.read
        mocked_s3.write(contents, destination_path)
        expect(subject.exists?(destination_path)).to be_truthy
      end
    end

    it "with no file" do
      expect(subject.exists?("unexisting_file.zip")).to be_falsey
    end
  end

  describe "#public_uri" do
    let(:destination_path) { "dest/file.jpeg" }

    it do
      with_test_file("camaloon.jpg") do |file, _|
        contents = file.read
        mocked_s3.write(contents, destination_path)
        expect(subject.public_uri(destination_path)).to eq "https://fake-bucket.s3.amazonaws.com/dest/file.jpeg"
      end
    end
  end
end
