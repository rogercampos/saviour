require 'spec_helper'

describe "concurrent processors" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  WAIT_TIME = 0.5

  let(:uploader) {
    Class.new(Saviour::BaseUploader) {
      store_dir { "/store/dir" }

      process_with_file do |file, filename|
        stash(attached_as => Time.now.to_f)
        sleep WAIT_TIME

        [file, filename]
      end

      after_upload do |stash|
        model.times = model.times.merge(stash)
      end
    }
  }

  let(:klass) {
    klass = Class.new(Test) {
      include Saviour::Model

      attr_accessor :times

      def initialize(*)
        super
        @times = {}
      end
    }
    klass.attach_file :file, uploader
    klass.attach_file :file_thumb, uploader
    klass.attach_file :file_thumb_2, uploader
    klass.attach_file :file_thumb_3, uploader
    klass
  }

  context 'on update' do
    it 'works concurrently with 4 workers' do
      a = klass.create!

      Saviour::Config.concurrent_workers = 4

      a.update_attributes! file: Saviour::StringSource.new("contents", "file.txt"),
                           file_thumb: Saviour::StringSource.new("contents", "file_2.txt"),
                           file_thumb_2: Saviour::StringSource.new("contents", "file_3.txt"),
                           file_thumb_3: Saviour::StringSource.new("contents", "file_4.txt")

      start_times = a.times.values.sort
      expect((start_times[0] - start_times[-1]).abs).to be_within(0.1).of(0)
    end

    it 'works in serial with 1 worker' do
      a = klass.create!

      Saviour::Config.concurrent_workers = 1

      a.update_attributes! file: Saviour::StringSource.new("contents", "file.txt"),
                           file_thumb: Saviour::StringSource.new("contents", "file_2.txt"),
                           file_thumb_2: Saviour::StringSource.new("contents", "file_3.txt"),
                           file_thumb_3: Saviour::StringSource.new("contents", "file_4.txt")

      start_times = a.times.values.sort
      expect((start_times[0] - start_times[-1]).abs).to be > WAIT_TIME * 3
    end

    it 'concurrency can be adjusted' do
      a = klass.create!

      Saviour::Config.concurrent_workers = 2

      a.update_attributes! file: Saviour::StringSource.new("contents", "file.txt"),
                           file_thumb: Saviour::StringSource.new("contents", "file_2.txt"),
                           file_thumb_2: Saviour::StringSource.new("contents", "file_3.txt"),
                           file_thumb_3: Saviour::StringSource.new("contents", "file_4.txt")

      start_times = a.times.values.sort
      expect((start_times[0] - start_times[1]).abs).to be_within(0.1).of(0)
      expect((start_times[2] - start_times[3]).abs).to be_within(0.1).of(0)
      expect((start_times[0] - start_times[-1]).abs).to be > WAIT_TIME
    end
  end

  context 'on create' do
    it 'works concurrently with 4 workers' do
      Saviour::Config.concurrent_workers = 4

      a = klass.create! file: Saviour::StringSource.new("contents", "file.txt"),
                        file_thumb: Saviour::StringSource.new("contents", "file_2.txt"),
                        file_thumb_2: Saviour::StringSource.new("contents", "file_3.txt"),
                        file_thumb_3: Saviour::StringSource.new("contents", "file_4.txt")

      start_times = a.times.values.sort
      expect((start_times[0] - start_times[-1]).abs).to be_within(0.1).of(0)
    end

    it 'works in serial with 1 worker' do
      Saviour::Config.concurrent_workers = 1

      a = klass.create! file: Saviour::StringSource.new("contents", "file.txt"),
                        file_thumb: Saviour::StringSource.new("contents", "file_2.txt"),
                        file_thumb_2: Saviour::StringSource.new("contents", "file_3.txt"),
                        file_thumb_3: Saviour::StringSource.new("contents", "file_4.txt")

      start_times = a.times.values.sort
      expect((start_times[0] - start_times[-1]).abs).to be > WAIT_TIME * 3
    end

    it 'concurrency can be adjusted' do
      Saviour::Config.concurrent_workers = 2

      a = klass.create! file: Saviour::StringSource.new("contents", "file.txt"),
                        file_thumb: Saviour::StringSource.new("contents", "file_2.txt"),
                        file_thumb_2: Saviour::StringSource.new("contents", "file_3.txt"),
                        file_thumb_3: Saviour::StringSource.new("contents", "file_4.txt")

      start_times = a.times.values.sort
      expect((start_times[0] - start_times[1]).abs).to be_within(0.1).of(0)
      expect((start_times[2] - start_times[3]).abs).to be_within(0.1).of(0)
      expect((start_times[0] - start_times[-1]).abs).to be > WAIT_TIME
    end
  end
end