require 'spec_helper'

describe Saviour::S3Storage do
  let(:injected_client) { Aws::S3::Client.new(stub_responses: true) }

  let(:storage_options) {
    {
      bucket: "fake-bucket",
      aws_access_key_id: "stub",
      aws_secret_access_key: "stub",
      region: "fake",
      public_url_prefix: "https://fake-bucket.s3.amazonaws.com"
    }
  }

  subject {
    storage = Saviour::S3Storage.new(storage_options)
    allow(storage).to receive(:client).and_return(injected_client)
    storage
  }

  context do
    it "fails when no keys are provided" do
      expect {
        Saviour::S3Storage.new(bucket: "fake-bucket")
      }.to raise_error(ArgumentError)
    end
  end

  describe "#write" do
    let(:destination_path) { "my/folder/file.jpeg" }

    it "writting a new file" do
      with_test_file("camaloon.jpg") do |file, _|
        contents = file.read
        expect(subject.write(contents, destination_path)).to be_truthy
      end
    end

    it "raises exception if key > 1024 bytes" do
      key = "a" * 1025
      expect { subject.write("contents", key) }.to raise_error.with_message(/The key in S3 must be at max 1024 bytes, this key is too big/)
    end

    it "ignores leading slash" do
      subject.write("trash contents", "/folder/file.out")
      expect(subject.exists?("folder/file.out")).to be_truthy
      expect(subject.exists?("/folder/file.out")).to be_truthy
      expect(subject.exists?("////folder/file.out")).to be_truthy
    end

    describe "fog create options" do
      let(:storage_options) {
        {
          bucket: "fake-bucket",
          aws_access_key_id: "stub",
          aws_secret_access_key: "stub",
          public_url_prefix: "https://fake-bucket.s3.amazonaws.com",
          create_options: { cache_control: 'max-age=31536000', acl: "public-read" },
          region: "fake"
        }
      }

      it "uses passed options to create new files in S3" do
        with_test_file("camaloon.jpg") do |file, _|
          contents = file.read
          expect(subject.write(contents, destination_path)).to be_truthy
        end
      end
    end
  end

  describe "#read" do
    let(:destination_path) { "dest/file.jpeg" }

    it "reads an existing file" do
      injected_client.stub_responses(:get_object, body: "hello")
      expect(subject.read(destination_path)).to eq "hello"
    end

    it "fails if the file do not exists" do
      injected_client.stub_responses(:get_object, 'NotFound')
      expect { subject.read("nope.rar") }.to raise_error(Saviour::FileNotPresent)
    end
  end

  describe "#delete" do
    let(:destination_path) { "dest/file.jpeg" }

    it "deletes an existing file" do
      expect(subject.delete(destination_path)).to be_truthy
    end
  end

  describe "#exists?" do
    let(:destination_path) { "dest/file.jpeg" }

    it "with existing file" do
      expect(subject.exists?(destination_path)).to be_truthy
    end

    it "with no file" do
      injected_client.stub_responses(:head_object, 'NotFound')
      expect(subject.exists?("unexisting_file.zip")).to be_falsey
    end
  end

  describe "#public_url" do
    let(:destination_path) { "dest/file.jpeg" }

    context do
      let(:storage_options) {
        {
          bucket: "fake-bucket",
          aws_access_key_id: "stub",
          aws_secret_access_key: "stub",
          region: "fake"
        }
      }

      it "fails if not provided the prefix" do
        expect { subject.public_url(destination_path) }.to raise_error(Saviour::S3Storage::MissingPublicUrlPrefix)
      end
    end

    context do
      let(:storage_options) {
        {
          bucket: "fake-bucket",
          aws_access_key_id: "stub",
          aws_secret_access_key: "stub",
          public_url_prefix: -> { "https://#{Time.now.hour}.s3.amazonaws.com" },
          region: "fake"
        }
      }

      it "allow to use a lambda for dynamic url prefixes" do
        allow(Time).to receive(:now).and_return(Time.new(2015, 1, 1, 13, 2, 1))

        expect(subject.public_url(destination_path)).to eq "https://13.s3.amazonaws.com/dest/file.jpeg"
      end
    end

    it do
      expect(subject.public_url(destination_path)).to eq "https://fake-bucket.s3.amazonaws.com/dest/file.jpeg"
    end
  end
end
