require 'spec_helper'

describe Saviour::LocalStorage do
  # operate only inside @tmpdir to not mess with test setup, Dir.mktmpdir
  subject { Saviour::LocalStorage.new(local_prefix: @tmpdir) }

  describe "#write" do
    let(:filename) { "output.jpg" }
    let(:destination_path) { File.join("/my/folder", filename) }

    it "writting a new file" do
      with_test_file("camaloon.jpg") do |file, _|
        file_destination = File.join(@tmpdir, destination_path)
        expect(File.file?(file_destination)).to be_falsey

        contents = file.read
        subject.write(contents, destination_path)

        expect(File.file?(file_destination)).to be_truthy
        expect(File.read(file_destination)).to eq contents
      end
    end

    it "overwritting an existing file" do
      file_destination = File.join(@tmpdir, destination_path)

      FileUtils.mkdir_p(File.dirname(file_destination))
      File.write(file_destination, "some dummy content")
      expect(File.file?(file_destination)).to be_truthy

      with_test_file("camaloon.jpg") do |file, _|
        contents = file.read
        subject.write(contents, destination_path)

        expect(File.file?(file_destination)).to be_truthy
        expect(File.read(file_destination)).to eq contents
      end
    end
  end

  describe "#read" do
    it "reads an existing file" do
      with_test_file("camaloon.jpg") do |file, _|
        expect(subject.read(File.basename(file.path))).to eq file.read
      end
    end

    it "fails if the file do not exists" do
      expect { subject.read("nope.rar") }.to raise_error
    end
  end

  describe "#delete" do
    it "deletes an existing file" do
      with_test_file("camaloon.jpg") do |file, _|
        expect(File.file?(file.path)).to be_truthy

        subject.delete(File.basename(file.path))
        expect(File.file?(file.path)).to be_falsey
      end
    end

    it "fails if the file do not exists" do
      expect { subject.delete("nope.rar") }.to raise_error
    end

    it "does not leave an empty dir behind" do
      with_test_file("camaloon.jpg") do |file, _|
        final_path = File.join(@tmpdir, "some/folder/dest.jpg")

        FileUtils.mkdir_p(File.dirname(final_path))
        FileUtils.cp file.path, final_path
        expect(File.file?(final_path)).to be_truthy

        subject.delete("/some/folder/dest.jpg")

        expect(File.file?(final_path)).to be_falsey
        expect(File.directory?(File.join(@tmpdir, "some/folder"))).to be_falsey
        expect(File.directory?(File.join(@tmpdir, "some"))).to be_falsey
      end
    end
  end

  describe "#exists?" do
    it "with existing file" do
      with_test_file("camaloon.jpg") do |file, _|
        expect(subject.exists?(File.basename(file.path))).to be_truthy
      end
    end

    it "with no file" do
      expect(subject.exists?("unexisting_file.zip")).to be_falsey
    end
  end

  describe "#public_url" do
    let(:destination_path) { "dest/file.jpeg" }

    context do
      subject { Saviour::LocalStorage.new(local_prefix: @tmpdir) }

      it "fails if not provided the prefix" do
        with_test_file("camaloon.jpg") do |file, _|
          expect {
            subject.public_url(File.basename(file.path))
          }.to raise_error
        end
      end
    end

    context do
      subject { Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: -> { "http://mywebsite.com/#{Time.now.hour}/uploads" }) }

      it do
        allow(Time).to receive(:now).and_return(Time.new(2015, 1, 1, 13, 2, 1))

        with_test_file("camaloon.jpg") do |file, filename|
          expect(subject.public_url(File.basename(file.path))).to eq "http://mywebsite.com/13/uploads/#{filename}"
        end
      end
    end

    context do
      subject { Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://mywebsite.com/uploads") }

      it do
        with_test_file("camaloon.jpg") do |file, filename|
          expect(subject.public_url(File.basename(file.path))).to eq "http://mywebsite.com/uploads/#{filename}"
        end
      end
    end
  end
end
