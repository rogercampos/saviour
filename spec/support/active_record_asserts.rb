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
  if ActiveRecord.gem_version >= Gem::Version.new("5.2.0")
    if data[:name] =~ /(Create|Update|Destroy)/
      sql = data[:sql]
      sql = sql.gsub("?").with_index { |_, i| ActiveRecord::Base.connection.quote(data[:type_casted_binds][i]) }

      AssertionsTracker.data.push(sql)
    end
  else
    AssertionsTracker.data.push(data[:sql]) if data[:name] == "SQL"
  end
end

