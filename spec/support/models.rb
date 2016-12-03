# Constant lookup in ruby works by lexical scope, so we can't create classes dynamically to test this.
class TestForSaviourFileResolution
  include Saviour::BasicModel

  def foo
    File.file?("/tasdasdasdmp/blabla.txt")
  end
end