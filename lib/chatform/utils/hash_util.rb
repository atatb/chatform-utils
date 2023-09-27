module Chatform
  module Utils
    class HashUtil
      class << self
        # Ref: https://stackoverflow.com/a/3699913
        # Style/EachWithObject: Use `each_with_object` instead of `inject`.
        # params:
        #   key_func: ->(k) { k.to_s }
        #   value_func: ->(v, _k = nil) { v.to_s }
        #   object_func: ->(obj, keys_ = []) {}
        def convert(object, keys = [], parent: nil, key_func: nil, value_func: nil, object_func: nil) # {{{
          return if object_func && object_func.call(object, keys) == false
          if object.is_a?(Hash)
            object.each_with_object({}) do |(k, v), obj|
              key = key_func ? key_func.call(k) : k
              value = convert(v, keys + [k], parent: object, key_func: key_func, value_func: value_func, object_func: object_func)
              next if value.nil?
              obj[key] = value
            end
          elsif object.is_a?(Array)
            object.each_with_object([]) do |v, obj|
              value = convert(v, keys, parent: obj, key_func: key_func, value_func: value_func, object_func: object_func)
              next if value.nil?
              obj << value
            end
          else
            # value_func ? value_func.call(object, keys.last, parent: parent) : object # removed parent as not used
            value_func ? value_func.call(object, keys.last) : object
          end
        end # }}}

        # Using yeild (explicit &block)
        def convert_value(object, key_func: nil, object_func: nil, &block) # {{{
          convert(object, key_func: key_func, value_func: block, object_func: object_func)
        end # }}}

        def convert_key(object, value_func: nil, object_func: nil, &block) # {{{
          convert(object, key_func: block, value_func: value_func, object_func: object_func)
        end # }}}

        def convert_object(object, key_func: nil, value_func: nil, &block) # {{{
          convert(object, key_func: key_func, value_func: value_func, object_func: block)
        end # }}}
      end
    end
  end
end
