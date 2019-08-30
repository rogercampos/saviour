require 'spec_helper'

describe "CRUD" do
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
        expect(a.update(file: example)).to be_truthy
      end
    end

    it do
      with_test_file("example.xml") do |example|
        a = klass.create!
        a.update(file: example)

        expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy
      end
    end

    it do
      with_test_file("example.xml") do |example, real_filename|
        a = klass.create!
        a.update(file: example)
        expect(a[:file]).to eq "/store/dir/#{real_filename}"
      end
    end

    it do
      with_test_file("example.xml") do |example|
        a = klass.create!
        a.update(file: example)

        example.rewind
        expect(a.file.read).to eq example.read
      end
    end

    it do
      with_test_file("example.xml") do |example|
        a = klass.create!
        a.update(file: example)

        expect(a.file.exists?).to be_truthy
      end
    end

    it do
      with_test_file("example.xml") do |example, real_filename|
        a = klass.create!
        a.update(file: example)

        expect(a.file.filename).to eq real_filename
      end
    end

    it do
      with_test_file("example.xml") do |example, real_filename|
        a = klass.create!
        a.update(file: example)

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

    context do
      let(:klass) {
        a = Class.new(Test) { include Saviour::Model }
        a.attach_file :file, uploader
        a.attach_file :file_thumb, uploader
        a
      }

      it "saves to db only once with multiple file attachments" do
        # 1 create + 1 update with two attributes
        expected_query = %Q{UPDATE "tests" SET "file" = '/store/dir/file.txt', "file_thumb" = '/store/dir/file.txt'}
        expect_to_yield_queries(count: 2, including: [expected_query]) do
          klass.create!(
              file: Saviour::StringSource.new("foo", "file.txt"),
              file_thumb: Saviour::StringSource.new("foo", "file.txt")
          )
        end
      end
    end

    it "can be created from another saviour attachment" do
      a = klass.create! file: Saviour::StringSource.new("contents", "file.txt")
      b = klass.create! file: a.file

      expect(b.file.read).to eq "contents"
      expect(b.file.filename).to eq "file.txt"
    end
  end

  describe "deletion" do
    it do
      with_test_file("example.xml") do |example|
        a = klass.create!
        a.update(file: example)
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
        a.update(file: example)

        expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy
        previous_location = a[:file]

        with_test_file("camaloon.jpg") do |example_2|
          a.update(file: example_2)
          expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy

          expect(Saviour::Config.storage.exists?(previous_location)).to be_falsey
        end
      end
    end

    it "does allow to update the same file to another contents in the same path" do
      a = klass.create! file: Saviour::StringSource.new("contents", "file.txt")

      a.update! file: Saviour::StringSource.new("foo", "file.txt")
      expect(Saviour::Config.storage.read(a[:file])).to eq "foo"
    end

    it "does not generate an extra query when saving the file with only attached changes" do
      a = klass.create!

      expect_to_yield_queries(count: 1) do
        a.update! file: Saviour::StringSource.new("foo", "file.txt")
      end
    end

    it "does generate an extra query when saving the file with an extra change" do
      a = klass.create!

      expect_to_yield_queries(count: 2) do
        a.update! name: "Text",
                             file: Saviour::StringSource.new("foo", "file.txt")
      end
    end

    describe "touch updated_at" do
      it "touches updated_at if the model has it" do
        time = Time.now - 4.years
        a = klass.create! updated_at: time
        a.update! file: Saviour::StringSource.new("foo", "file.txt")

        expect(a.updated_at).to be > time + 2.years
      end

      context do
        let(:klass) {
          a = Class.new(TestNoTimestamp) { include Saviour::Model }
          a.attach_file :file, uploader
          a
        }

        it "works with models that do not have updated_at" do
          a = klass.create!
          expect(a).not_to respond_to(:updated_at)
          a.update! file: Saviour::StringSource.new("foo", "file.txt")
          expect(a.file.read).to eq "foo"
        end
      end
    end

    context do
      let(:klass) {
        a = Class.new(Test) { include Saviour::Model }
        a.attach_file :file, uploader
        a.attach_file :file_thumb, uploader
        a
      }

      it "saves to db only once with multiple file attachments" do
        a = klass.create!

        expected_query = %Q{UPDATE "tests" SET "file" = '/store/dir/file.txt', "file_thumb" = '/store/dir/file.txt'}
        expect_to_yield_queries(count: 1, including: [expected_query]) do
          a.update!(
              file: Saviour::StringSource.new("foo", "file.txt"),
              file_thumb: Saviour::StringSource.new("foo", "file.txt")
          )
        end
      end
    end
  end

  describe "dupping" do
    let(:uploader) {
      Class.new(Saviour::BaseUploader) {
        store_dir { "/store/dir/#{model.id}" }
      }
    }

    it "with no attachment" do
      a = klass.create!
      b = a.dup
      b.save!
      expect(b[:file]).to be_nil
    end

    it "on non persisted object with no attachment" do
      a = klass.new
      b = a.dup
      b.save!
      expect(b[:file]).to be_nil
    end

    it "on non persisted object with attachment" do
      a = klass.new file: Saviour::StringSource.new("contents", "file.txt")
      b = a.dup
      b.save!
      expect(b[:file]).to_not be_nil
      expect(Saviour::Config.storage.exists?(b[:file])).to be_truthy
    end

    it "creates a non persisted file attachment with initially clear db paths" do
      a = klass.create! file: Saviour::StringSource.new("contents", "file.txt")
      expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy

      b = a.dup
      expect(b).to_not be_persisted
      expect(b.file).to_not be_persisted
      expect(b[:file]).to be_nil
    end

    it "can be saved" do
      a = klass.create! file: Saviour::StringSource.new("contents", "file.txt")
      path_a = a[:file]

      b = a.dup
      b.save!
      path_b = b[:file]

      expect(path_a).to eq "/store/dir/#{a.id}/file.txt"
      expect(path_b).to eq "/store/dir/#{b.id}/file.txt"
      expect(Saviour::Config.storage.exists?(path_b)).to be_truthy
      expect(Saviour::Config.storage.read(path_a)).to eq Saviour::Config.storage.read(path_b)
    end
  end

  describe "presence" do
    it "false when no assigned file" do
      a = klass.create!
      expect(a.file?).to be_falsey
    end

    it "true when no persisted but assigned" do
      a = klass.create!
      a.file = Saviour::StringSource.new("contents", "file.txt")
      expect(a.file?).to be_truthy
    end

    it "true when persisted and assigned" do
      a = klass.create! file: Saviour::StringSource.new("contents", "file.txt")
      expect(a.file?).to be_truthy
    end
  end
end
