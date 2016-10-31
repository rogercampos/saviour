require 'spec_helper'

describe "validations saving a new file" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  let(:uploader) {
    Class.new(Saviour::BaseUploader) {
      store_dir { "/store/dir" }
    }
  }

  let(:base_klass) {
    a = Class.new(Test) { include Saviour::Model }
    a.attach_file :file, uploader
    a
  }

  it "fails at block validation" do
    klass = Class.new(base_klass) do
      attach_validation(:file) do |contents, _|
        errors.add(:file, "Cannot start with X") if contents[0] == 'X'
      end
    end

    with_test_file("example.xml") do |example|
      allow(example).to receive(:read).and_return("X-Extra contents for the file")
      a = klass.new
      a.file = example
      expect(a).not_to be_valid
      expect(a.errors[:file][0]).to eq "Cannot start with X"
    end

    with_test_file("example.xml") do |example|
      a = klass.new
      a.file = example
      expect(a).to be_valid
      expect(a.save).to be_truthy
    end
  end


  it "fails at method validation" do
    klass = Class.new(base_klass) do
      attach_validation :file, :check_filesize

      def check_filesize(contents, _)
        errors.add(:file, "Filesize must be less than 10 bytes") if contents.bytesize >= 10
      end
    end

    with_test_file("example.xml") do |example|
      allow(example).to receive(:read).and_return("1234567890")
      a = klass.new
      a.file = example
      expect(a).not_to be_valid
      expect(a.errors[:file][0]).to eq "Filesize must be less than 10 bytes"
    end

    with_test_file("example.xml") do |example|
      allow(example).to receive(:read).and_return("123456789")
      a = klass.new
      a.file = example
      expect(a).to be_valid
    end
  end

  it "combined validatinos" do
    klass = Class.new(base_klass) do
      attach_validation :file, :check_filesize
      attach_validation(:file) do |contents, _|
        errors.add(:file, "Cannot start with X") if contents[0] == 'X'
      end

      def check_filesize(contents, _)
        errors.add(:file, "Filesize must be less than 10 bytes") if contents.bytesize >= 10
      end
    end

    with_test_file("example.xml") do |example|
      allow(example).to receive(:read).and_return("X-Ex")
      a = klass.new
      a.file = example
      expect(a).not_to be_valid
      expect(a.errors[:file][0]).to eq "Cannot start with X"
    end

    with_test_file("example.xml") do |example|
      allow(example).to receive(:read).and_return("Ex too long content")
      a = klass.new
      a.file = example
      expect(a).not_to be_valid
      expect(a.errors[:file][0]).to eq "Filesize must be less than 10 bytes"
    end

    # Consistent order
    with_test_file("example.xml") do |example|
      allow(example).to receive(:read).and_return("X-Ex too long content")
      a = klass.new
      a.file = example
      expect(a).not_to be_valid
      expect(a.errors[:file][0]).to eq "Filesize must be less than 10 bytes"
      expect(a.errors[:file][1]).to eq "Cannot start with X"
    end
  end

  it "validates by filename" do
    klass = Class.new(base_klass) do
      attach_validation :file, :check_filename

      def check_filename(_, filename)
        errors.add(:file, "Only .jpg files") unless filename =~ /\.jpg/
      end
    end

    with_test_file("example.xml") do |example|
      allow(example).to receive(:read).and_return("X-Ex")
      a = klass.new
      a.file = example
      expect(a).not_to be_valid
      expect(a.errors[:file][0]).to eq "Only .jpg files"
    end

    with_test_file("camaloon.jpg") do |example|
      allow(example).to receive(:read).and_return("X-Ex")
      a = klass.new
      a.file = example
      expect(a).to be_valid
    end
  end

  it "receives the attached_as information" do
    klass = Class.new(base_klass) do
      attach_validation :file, :check_filename

      def check_filename(_, _, opts)
        errors.add(:file, "Received error in #{opts[:attached_as]}")
      end
    end

    with_test_file("example.xml") do |example|
      a = klass.new file: example
      expect(a).not_to be_valid
      expect(a.errors[:file][0]).to eq "Received error in file"
    end
  end

  context "versions are validated" do
    let(:uploader) {
      Class.new(Saviour::BaseUploader) {
        store_dir { "/store/dir" }
        version(:thumb)
      }
    }
    let(:klass) {
      Class.new(base_klass) do
        attach_validation(:file) do |contents, _, opts|
          errors.add(:file, "Cannot start with X in version #{opts[:version]}") if contents[0] == 'X'
        end
      end
    }

    it do
      a = klass.create!
      a.file.assign Saviour::StringSource.new("correct contents")
      a.file(:thumb).assign Saviour::StringSource.new("X Incorrect contents")

      expect(a).not_to be_valid
      expect(a.errors[:file][0]).to eq "Cannot start with X in version thumb"
    end
  end
end
