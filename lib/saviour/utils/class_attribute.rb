# Port and simplification of ActiveSupport class attribute
module Saviour
  module ClassAttribute
    def class_attribute(*attrs)
      attrs.each do |name|
        singleton_class.instance_eval do
          undef_method(name) if method_defined?(name)
        end

        define_singleton_method(name) { nil }

        singleton_class.instance_eval do
          undef_method("#{name}=") if method_defined?("#{name}=")
        end

        define_singleton_method("#{name}=") do |val|
          singleton_class.class_eval do
            undef_method(name) if method_defined?(name)
            define_method(name) { val }
          end
          val
        end
      end
    end
  end
end