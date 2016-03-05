require 'spec_helper'

describe Saviour do
  it "raises error if included in a non active record class" do
    expect {
      Class.new do
        include Saviour
      end
    }.to raise_error(Saviour::NoActiveRecordDetected)
  end

  it "error if column not present" do
    expect {
      Class.new(Test) do
        include Saviour

        attach_file :not_present, Saviour::BaseUploader
      end
    }.to raise_error(RuntimeError)
  end

  it "error if column not present on version" do
    expect {
      Class.new(Test) do
        include Saviour

        attach_file :file, Saviour::BaseUploader, versions: [:not_present]
      end
    }.to raise_error(RuntimeError)
  end

  it "does not raise error if table is not present" do
    allow(Test).to receive(:table_exists?).and_return(false)

    expect {
      Class.new(Test) do
        include Saviour

        attach_file :not_present, Saviour::BaseUploader
      end
    }.to_not raise_error
  end
end
