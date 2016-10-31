class Test < ActiveRecord::Base

end

# Constant lookup in ruby works by lexical scope, so we can't create classes dynamically to test this.
class TestForSaviourFileResolution < Test
  include Saviour::Model

  def foo
    File.file?("/tasdasdasdmp/blabla.txt")
  end
end