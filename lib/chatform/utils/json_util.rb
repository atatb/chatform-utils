require 'json'

module Chatform
  module Utils
    class JsonUtil
      PRETTY_STATE_PROTOTYPE = {
        indent: '  ',
        space: ' ',
        space_before: '',
        object_nl: "\n",
        array_nl: "\n"
      }.freeze

      # params:
      #   value_func: ->(v, _keys, _state) { v }
      #   object_func: ->(_obj, _keys, _state
      def initialize(opts: PRETTY_STATE_PROTOTYPE, value_func: nil, object_func: nil)
        @value_func = value_func
        @object_func = object_func
        # JSON::Ext::Generator::State
        #   https://github.com/flori/json/blob/master/lib/json/pure/generator.rb#L85
        @state = JSON.state.new(opts)
      end

      # Ref: https://github.com/flori/json/blob/master/lib/json/pure/generator.rb
      # https://github.com/ruby/json/blob/master/lib/json/truffle_ruby/generator.rb#L328
      def generate(obj, keys: [])
        return if @object_func && @object_func.call(obj, keys, @state) == false

        if obj.is_a?(Hash)
          hash_to_json(obj, keys)
        elsif obj.is_a?(Array)
          array_to_json(obj, keys)
        else
          @value_func ? @value_func.call(obj, keys, @state) : obj.to_json(@state)
        end
      end

      private

      attr_reader :state

      # Ref: https://github.com/flori/json/blob/master/lib/json/pure/generator.rb#L294
      def hash_to_json(obj, keys) # {{{
        delim = ','
        delim << state.object_nl
        result = '{'
        result << state.object_nl
        depth = state.depth += 1
        first = true
        indent = !state.object_nl.empty?
        obj.each do |key, value|
          v = generate(value, keys: keys + [key])
          next if v.nil? || v == nil.to_json(state) # value is to be converted by to_json
          result << delim unless first
          result << state.indent * depth if indent
          result << key.to_s.to_json(state)
          result << state.space_before
          result << ':'
          result << state.space
          result << v
          # result << if value.respond_to?(:to_json)
          #             v
          #           else
          #             %("#{String(value)}")
          #           end
          first = false
        end
        depth = state.depth -= 1
        result << state.object_nl unless first # NOTE: avoid {\n\n}
        result << state.indent * depth if indent
        result << '}'
        result
      end # }}}

      # Ref: https://github.com/flori/json/blob/master/lib/json/pure/generator.rb#L337
      def array_to_json(obj, keys) # {{{
        delim = ','
        delim << state.array_nl
        result = '['
        result << state.array_nl
        depth = state.depth += 1
        first = true
        indent = !state.array_nl.empty?
        obj.each do |value|
          v = generate(value, keys: keys)
          next if v.nil? || v == nil.to_json(state)
          result << delim unless first
          result << state.indent * depth if indent
          # result << generate(value, state, keys: keys)
          result << v
          # result << if value.respond_to?(:to_json)
          #             generate(value, state, keys: keys)
          #           else
          #             %("#{String(value)}")
          #           end
          first = false
        end
        depth = state.depth -= 1
        result << state.array_nl
        result << state.indent * depth if indent
        result << ']'
        result
      end # }}}
    end
  end
end
