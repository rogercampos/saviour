module ActiveRecordAssertions
  def expect_to_yield_queries(count: nil, including: [])
    AssertionsTracker.clear!
    yield

    expect(AssertionsTracker.data.size).to eq(count) if count

    including.each do |query|
      expect(AssertionsTracker.data).to include a_string_matching(Regexp.new(query))
    end
  end
end

module AssertionsTracker
  def self.data
    @data ||= []
  end

  def self.clear!
    @data = []
  end
end

RSpec.configure do |config|
  config.before do
    AssertionsTracker.clear!
  end

  config.include ActiveRecordAssertions
end

ActiveSupport::Notifications.subscribe "sql.active_record" do |name, started, finished, unique_id, data|
  AssertionsTracker.data.push(data[:sql]) if data[:name] == "SQL"
end

