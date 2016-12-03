require 'spec_helper'

describe "saving a new file" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  let(:uploader) {
    Class.new(Saviour::BaseUploader) do
      store_dir { "/store/dir" }

      version(:thumb) do
        store_dir { "/versions/store/dir" }
      end
    end
  }

  let(:klass) {
    a = Class.new { include Saviour::BasicModel }
    a.attach_file :file, uploader
    a
  }

  describe "creation following main file" do
    it do
      with_test_file("example.xml") do |example|
        a = klass.new
        a.file = example
        Saviour::LifeCycle.new(a).save!

        path = a.file(:thumb).persisted_path
        expect(path).not_to be_nil
        expect(Saviour::Config.storage.exists?(path)).to be_truthy
      end
    end
  end

  describe "deletion" do
    it do
      with_test_file("example.xml") do |example|
        a = klass.new
        a.file = example
        Saviour::LifeCycle.new(a).save!

        expect(Saviour::Config.storage.exists?(a.file(:thumb).persisted_path)).to be_truthy
        expect(Saviour::Config.storage.exists?(a.file.persisted_path)).to be_truthy

        Saviour::LifeCycle.new(a).delete!
        expect(Saviour::Config.storage.exists?(a.file(:thumb).persisted_path)).to be_falsey
        expect(Saviour::Config.storage.exists?(a.file.persisted_path)).to be_falsey
      end
    end
  end

  describe "changes following main file" do
    it do
      with_test_file("example.xml") do |example|
        a = klass.new
        a.file = example
        Saviour::LifeCycle.new(a).save!
        path = a.file(:thumb).persisted_path
        expect(Saviour::Config.storage.exists?(path)).to be_truthy

        with_test_file("camaloon.jpg") do |file|
          a.file = file
          Saviour::LifeCycle.new(a).save!
          path = a.file(:thumb).persisted_path

          expect(Saviour::Config.storage.exists?(path)).to be_truthy
          file.rewind
          expect(a.file(:thumb).read).to eq file.read
        end
      end
    end
  end

  describe "accessing file features directly" do
    let(:uploader) {
      Class.new(Saviour::BaseUploader) do
        store_dir { "/store/dir" }

        version(:thumb) do
          store_dir { "/versions/store/dir" }
          process { |contents, name| ["#{contents}_for_version_thumb", name] }
        end
      end
    }

    it "#url" do
      with_test_file("example.xml") do |example, name|
        a = klass.new
        a.file = example
        Saviour::LifeCycle.new(a).save!

        versioned_name = "#{File.basename(name, ".*")}_thumb#{File.extname(name)}"
        expect(a.file(:thumb).url).to eq "http://domain.com/versions/store/dir/#{versioned_name}"
      end
    end

    it "#read" do
      with_test_file("text.txt") do |example|
        a = klass.new
        a.file = example
        Saviour::LifeCycle.new(a).save!

        expect(a.file(:thumb).read).to eq "Hello world\n_for_version_thumb"
      end
    end

    it "#delete" do
      with_test_file("example.xml") do |example|
        a = klass.new
        a.file = example
        Saviour::LifeCycle.new(a).save!
        expect(Saviour::Config.storage.exists?(a.file(:thumb).persisted_path)).to be_truthy
        expect(Saviour::Config.storage.exists?(a.file.persisted_path)).to be_truthy

        a.file(:thumb).delete

        expect(Saviour::Config.storage.exists?(a.file(:thumb).persisted_path)).to be_falsey
        expect(Saviour::Config.storage.exists?(a.file.persisted_path)).to be_truthy
      end
    end

    it "#exists?" do
      with_test_file("example.xml") do |example|
        a = klass.new
        a.file = example
        Saviour::LifeCycle.new(a).save!
        expect(a.file(:thumb).exists?).to be_truthy
      end
    end
  end

  describe "assign specific version after first creation" do
    it do
      with_test_file("example.xml") do |example|
        a = klass.new
        a.file = example
        Saviour::LifeCycle.new(a).save!

        thumb_path = a.file(:thumb).persisted_path
        expect(Saviour::Config.storage.exists?(thumb_path)).to be_truthy
        expect(thumb_path).to eq "/versions/store/dir/#{File.basename(example, ".*")}_thumb.xml"

        with_test_file("camaloon.jpg") do |ex2, filename|
          a.file(:thumb).assign(ex2)
          Saviour::LifeCycle.new(a).save!
          thumb_path = a.file(:thumb).persisted_path

          expect(Saviour::Config.storage.exists?(thumb_path)).to be_truthy
          expect(thumb_path).to eq "/versions/store/dir/#{File.basename(filename, ".*")}.jpg"
        end
      end
    end

    context do
      let(:uploader) {
        Class.new(Saviour::BaseUploader) do
          store_dir { "/store/dir" }

          version(:thumb) do
            store_dir { "/versions/store/dir" }
            process { |_, filename| ["modified_content", filename] }
          end
        end
      }

      it "runs the processors for that version only" do
        with_test_file("example.xml") do |example|
          a = klass.new
          a.file = example
          Saviour::LifeCycle.new(a).save!
          thumb_path = a.file(:thumb).persisted_path

          expect(Saviour::Config.storage.exists?(thumb_path)).to be_truthy
          expect(thumb_path).to eq "/versions/store/dir/#{File.basename(example, ".*")}_thumb.xml"

          with_test_file("camaloon.jpg") do |ex2, filename|
            a.file(:thumb).assign(ex2)

            Saviour::LifeCycle.new(a).save!
            thumb_path = a.file(:thumb).persisted_path

            expect(Saviour::Config.storage.exists?(thumb_path)).to be_truthy
            expect(thumb_path).to eq "/versions/store/dir/#{File.basename(filename, ".*")}.jpg"
            expect(Saviour::Config.storage.read(thumb_path)).to eq "modified_content"
          end
        end
      end
    end
  end

  describe "respects version assignation vs main file assignation on conflict" do
    it do
      a = klass.new

      with_test_file("example.xml") do |file1, fname1|
        with_test_file("camaloon.jpg") do |file2, fname2|
          a.file.assign(file1)
          a.file(:thumb).assign(file2)
          Saviour::LifeCycle.new(a).save!

          expect(a.file.persisted_path).to eq "/store/dir/#{fname1}"
          expect(a.file(:thumb).persisted_path).to eq "/versions/store/dir/#{fname2}"
        end
      end
    end
  end
end
