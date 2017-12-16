require 'spec_helper'

describe "method override" do
  before { allow(Saviour::Config).to receive(:storage).and_return(Saviour::LocalStorage.new(local_prefix: @tmpdir, public_url_prefix: "http://domain.com")) }

  it "works with user redefinition" do
    uploader = Class.new(Saviour::BaseUploader) {
      store_dir { "/store/dir" }
      process { |contents, filename| [contents, "foo_#{filename}"] }
    }
    klass = Class.new(Test) { include Saviour::Model }
    klass.attach_file :file, uploader
    klass.class_eval do
      attr_accessor :setter_bean, :getter_bean

      def file=(value)
        self.setter_bean = 'setted!'
        super
      end

      def file
        self.getter_bean = 'getted!'
        super
      end
    end

    a = klass.create! file: Saviour::StringSource.new("content", "houhou.txt")
    expect(a.setter_bean).to eq 'setted!'
    expect(a.file.filename).to eq "foo_houhou.txt"
    expect(a.file.url).to eq 'http://domain.com/store/dir/foo_houhou.txt'
    expect(a.getter_bean).to eq 'getted!'
  end
end