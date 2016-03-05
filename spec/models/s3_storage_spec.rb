require 'spec_helper'

describe Saviour::S3Storage do
  subject { Saviour::S3Storage.new(bucket: "fake-bucket", aws_access_key_id: "stub", aws_secret_access_key: "stub", public_url_prefix: "https://fake-bucket.s3.amazonaws.com") }
  let!(:mocked_s3) { MockedS3Helper.new }
  before { mocked_s3.start!(bucket_name: "fake-bucket") }

  context do
    it "fails when no keys are provided" do
      expect {
        Saviour::S3Storage.new(bucket: "fake-bucket")
      }.to raise_error(ArgumentError)
    end

    it "fails when the bucket doesn't exists" do
      expect {
        Saviour::S3Storage.new(bucket: "no-bucket", aws_access_key_id: "stub", aws_secret_access_key: "stub")
      }.to raise_error(ArgumentError)
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

    describe "overwritting" do
      context "without overwrite protection" do
        subject {
          Saviour::S3Storage.new(
              bucket: "fake-bucket",
              aws_access_key_id: "stub",
              aws_secret_access_key: "stub",
              public_url_prefix: "https://fake-bucket.s3.amazonaws.com",
              overwrite_protection: false
          )
        }

        it "overwrites the existing file" do
          mocked_s3.write("some dummy contents", destination_path)
          expect(mocked_s3.exists?(destination_path)).to be_truthy

          with_test_file("camaloon.jpg") do |file, _|
            contents = file.read
            subject.write(contents, destination_path)
            expect(mocked_s3.read(destination_path)).to eq contents
          end
        end
      end

      context "with overwrite protection" do
        it "raises an exception" do
          mocked_s3.write("some dummy contents", destination_path)
          expect(mocked_s3.exists?(destination_path)).to be_truthy

          with_test_file("camaloon.jpg") do |file, _|
            contents = file.read
            expect { subject.write(contents, destination_path) }.to raise_error(RuntimeError)
          end
        end
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
      expect { subject.read("nope.rar") }.to raise_error(RuntimeError)
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
      expect { subject.delete("nope.rar") }.to raise_error(RuntimeError)
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

  describe "#public_url" do
    let(:destination_path) { "dest/file.jpeg" }

    context do
      subject { Saviour::S3Storage.new(bucket: "fake-bucket", aws_access_key_id: "stub", aws_secret_access_key: "stub") }

      it "fails if not provided the prefix" do
        with_test_file("camaloon.jpg") do |file, _|
          contents = file.read
          mocked_s3.write(contents, destination_path)
          expect { subject.public_url(destination_path) }.to raise_error(RuntimeError)
        end
      end
    end

    context do
      subject { Saviour::S3Storage.new(bucket: "fake-bucket", aws_access_key_id: "stub", aws_secret_access_key: "stub", public_url_prefix: -> { "https://#{Time.now.hour}.s3.amazonaws.com" }) }

      it "allow to use a lambda for dynamic url prefixes" do
        allow(Time).to receive(:now).and_return(Time.new(2015, 1, 1, 13, 2, 1))

        with_test_file("camaloon.jpg") do |file, _|
          contents = file.read
          mocked_s3.write(contents, destination_path)
          expect(subject.public_url(destination_path)).to eq "https://13.s3.amazonaws.com/dest/file.jpeg"
        end
      end
    end

    it do
      with_test_file("camaloon.jpg") do |file, _|
        contents = file.read
        mocked_s3.write(contents, destination_path)
        expect(subject.public_url(destination_path)).to eq "https://fake-bucket.s3.amazonaws.com/dest/file.jpeg"
      end
    end
  end
end
