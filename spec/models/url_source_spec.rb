require 'spec_helper'

describe Saviour::UrlSource do
  describe "initialization" do
    it "fails if no valid uri" do
      expect { Saviour::UrlSource.new("%^7QQ#%%@#@@") }.to raise_error(ArgumentError).with_message(/is not a valid URI/)
    end

    it "does not fail if provided a valid uri" do
      expect(Saviour::UrlSource.new("http://domain.com/file.jpg")).to be_truthy
    end
  end

  describe "#original_filename" do
    it "is extracted from the passed uri" do
      a = Saviour::UrlSource.new("http://domain.com/file.jpg")
      expect(a.original_filename).to eq "file.jpg"
    end
  end

  describe "#path" do
    it "is extracted from te passed uri" do
      a = Saviour::UrlSource.new("http://domain.com/path/file.jpg")
      expect(a.path).to eq "/path/file.jpg"
    end
  end

  describe "#read" do
    it "fails if the uri cannot be accessed" do
      allow(Net::HTTP).to receive(:get_response).and_return(Net::HTTPNotFound)

      a = Saviour::UrlSource.new("http://aboubaosdubioaubosdubaou.com/path/file.jpg")
      expect { a.read }.to raise_error(RuntimeError).with_message(/failed after 3 attempts/)
    end

    it "retries the request 3 times on error" do
      expect(Net::HTTP).to receive(:get_response).and_return(Net::HTTPNotFound, Net::HTTPNotFound)
      expect(Net::HTTP).to receive(:get_response).and_call_original
      a = Saviour::UrlSource.new("http://example.org/")
      expect(a.read.length).to be > 100
    end

    it "succeds if the uri is valid" do
      a = Saviour::UrlSource.new("http://example.org/")
      expect(a.read.length).to be > 100
    end

    it "follows redirects" do
      response = Net::HTTPRedirection.new "1.1", "301", "Redirect"
      expect(response).to receive(:[]).with("location").and_return("http://example.org")

      expect(Net::HTTP).to receive(:get_response).and_return(response)
      expect(Net::HTTP).to receive(:get_response).and_call_original

      a = Saviour::UrlSource.new("http://faked.blabla")
      expect(a.read.length).to be > 100
    end

    it "does not follow more than 10 redirects" do
      response = Net::HTTPRedirection.new "1.1", "301", "Redirect"
      expect(response).to receive(:[]).with("location").exactly(10).times.and_return("http://example.org")
      expect(Net::HTTP).to receive(:get_response).exactly(10).times.and_return(response)

      expect { Saviour::UrlSource.new("http://faked.blabla").read }.to raise_error(RuntimeError).with_message(/Max number of allowed redirects reached \(10\) when resolving/)
    end

    it "fails if the redirected location is not a valid URI" do
      response = Net::HTTPRedirection.new "1.1", "301", "Redirect"
      expect(response).to receive(:[]).with("location").and_return("http://example.org/%@(&#<<<<")

      expect(Net::HTTP).to receive(:get_response).and_return(response)

      expect { Saviour::UrlSource.new("http://faked.blabla").read }.to raise_error(ArgumentError).with_message(/is not a valid URI/)
    end
  end
end
