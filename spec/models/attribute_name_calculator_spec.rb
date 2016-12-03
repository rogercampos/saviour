require 'spec_helper'

describe Saviour::AttributeNameCalculator do
  it "returns the attached_as value" do
    expect(Saviour::AttributeNameCalculator.new("preview_file").name).to eq "preview_file"
  end

  it "appends the version if provided" do
    expect(Saviour::AttributeNameCalculator.new("preview_file", "thumb").name).to eq "preview_file_thumb"
  end
end