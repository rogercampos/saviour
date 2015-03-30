require 'spec_helper'

describe Saviour do
  it "raises error if included in a non active record class" do
    expect {
      Class.new do
        include Saviour
      end
    }.to raise_error(Saviour::NoActiveRecordDetected)
  end

end