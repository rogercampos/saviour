require 'spec_helper'

describe "transactional behavior" do
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

  describe "deletion" do
    it "deletes on after commit" do
      with_test_file("example.xml") do |example|
        a = klass.create! file: example
        expect(a.file.exists?).to be_truthy

        ActiveRecord::Base.transaction do
          expect(a.destroy).to be_truthy
          expect(klass.count).to eq 0
          expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy
        end

        expect(Saviour::Config.storage.exists?(a[:file])).to be_falsey
      end
    end

    it "doesn't delete on rollback" do
      with_test_file("example.xml") do |example|
        a = klass.create! file: example
        expect(a.file.exists?).to be_truthy

        ActiveRecord::Base.transaction do
          expect(a.destroy).to be_truthy
          expect(klass.count).to eq 0
          raise ActiveRecord::Rollback
        end

        expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy
      end
    end
  end

  describe "creation" do
    it "upload happens right after insert" do
      with_test_file("example.xml") do |example|
        a = nil

        ActiveRecord::Base.transaction do
          a = klass.create! file: example
          expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy
        end

        expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy
      end
    end

    it "upload is deleted on rollback" do
      with_test_file("example.xml") do |example|
        path = nil

        ActiveRecord::Base.transaction do
          a = klass.create! file: example
          path = a[:file]
          expect(Saviour::Config.storage.exists?(path)).to be_truthy
          raise ActiveRecord::Rollback
        end

        expect(klass.count).to eq 0
        expect(Saviour::Config.storage.exists?(path)).to be_falsey
      end
    end
  end

  describe "update with a different path" do
    it "leaves the previous file alive until after commit, then deletes it" do
      with_test_file("example.xml") do |example|
        a = klass.create! file: example
        path1 = a[:file]
        expect(Saviour::Config.storage.exists?(path1)).to be_truthy

        with_test_file("camaloon.jpg") do |file2|
          ActiveRecord::Base.transaction do
            a.update! file: file2

            expect(Saviour::Config.storage.exists?(path1)).to be_truthy
            expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy
          end

          expect(Saviour::Config.storage.exists?(path1)).to be_falsey
        end
      end
    end

    it "on rollback doesn't delete previous file and deletes new file" do
      with_test_file("example.xml") do |example|
        a = klass.create! file: example
        path1 = a[:file]
        path2 = nil
        expect(Saviour::Config.storage.exists?(path1)).to be_truthy

        with_test_file("camaloon.jpg") do |file2|
          ActiveRecord::Base.transaction do
            a.update! file: file2
            path2 = a[:file]

            expect(Saviour::Config.storage.exists?(path1)).to be_truthy
            expect(Saviour::Config.storage.exists?(path2)).to be_truthy

            raise ActiveRecord::Rollback
          end

          expect(a.reload[:file]).to eq path1

          expect(Saviour::Config.storage.exists?(path1)).to be_truthy
          expect(Saviour::Config.storage.exists?(path2)).to be_falsey
        end
      end
    end
  end

  describe "update with the same path" do
    before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

    it "leaves the previous file contents on rollback" do
      a = klass.create! file: Saviour::StringSource.new("original content", "file.txt")

      expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy
      expect(Saviour::Config.storage.read(a[:file])).to eq "original content"

      ActiveRecord::Base.transaction do
        a.update! file: Saviour::StringSource.new("new content", "file.txt")
        expect(Saviour::Config.storage.read(a[:file])).to eq "new content"
        raise ActiveRecord::Rollback
      end

      expect(Saviour::Config.storage.exists?(a[:file])).to be_truthy
      expect(Saviour::Config.storage.read(a[:file])).to eq "original content"
    end
  end
end
