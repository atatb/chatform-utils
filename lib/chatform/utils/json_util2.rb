# frozen_string_literal: true
require 'json'
require 'stringio'

module Chatform
  module Utils
    # Enhanced JSON generator with customizable handlers and formatting options
    class JsonUtil2
      PRETTY_STATE_PROTOTYPE = {
        indent: '  ',
        space: ' ',
        space_before: '',
        object_nl: "\n",
        array_nl: "\n"
      }.freeze

      COMPACT_STATE_PROTOTYPE = {
        indent: '',
        space: '',
        space_before: '',
        object_nl: '',
        array_nl: ''
      }.freeze

      attr_reader :options, :skip_nil, :sort_keys

      # Initialize with format options
      # @param format [Symbol, Hash] :pretty, :compact, or custom Hash options
      # @param skip_nil [Boolean] whether to skip nil values (default: true)
      # @param sort_keys [Boolean] whether to sort hash keys (default: false)
      def initialize(format: :pretty, skip_nil: true, sort_keys: false)
        @handlers = []
        @skip_nil = skip_nil
        @sort_keys = sort_keys
        @options = case format
                   when :pretty then PRETTY_STATE_PROTOTYPE
                   when :compact then COMPACT_STATE_PROTOTYPE
                   when Hash then format
                   else
                     raise ArgumentError, "Invalid format: #{format}. Expected :pretty, :compact, or Hash"
                   end
        @state = JSON.state.new(@options)
      end

      # Create instance with custom options
      # @param opts [Hash] JSON state options
      # @param skip_nil [Boolean] whether to skip nil values
      # @param sort_keys [Boolean] whether to sort hash keys
      # @return [JsonUtil2] new instance
      def self.with_options(opts, skip_nil: true, sort_keys: false)
        raise InvalidPatternError, 'Options must be a Hash' unless opts.is_a?(Hash)
        new(format: opts, skip_nil: skip_nil, sort_keys: sort_keys)
      end

      # Factory methods for common formats
      def self.pretty(skip_nil: true, sort_keys: false)
        new(format: :pretty, skip_nil: skip_nil, sort_keys: sort_keys)
      end

      def self.compact(skip_nil: true, sort_keys: false)
        new(format: :compact, skip_nil: skip_nil, sort_keys: sort_keys)
      end

      # Add a handler to the processing chain
      # @yield [obj, keys, state] handler block
      # @return [self] for method chaining
      def add_handler(&block)
        raise InvalidHandlerError, 'Handler block is required' unless block_given?
        @handlers << block
        self
      end

      # Clear all handlers
      # @return [self] for method chaining
      def clear_handlers
        @handlers.clear
        self
      end

      # Get the number of registered handlers
      # @return [Integer] handler count
      def handler_count
        @handlers.size
      end

      # Helper methods {{{
      # Add handler for specific type
      # @param type [Class, Module] the type to handle
      # @yield [obj, keys, state] handler block for matching objects
      # @return [self] for method chaining
      def handle_type(type, &block)
        raise InvalidPatternError, 'Type must be a Class or Module' unless type.is_a?(Class) || type.is_a?(Module)
        raise InvalidHandlerError, 'Handler block is required' unless block_given?

        add_handler do |obj, keys, state|
          if obj.is_a?(type)
            result = block.call(obj, keys, state)
            # Return nil to skip the element
            result.nil? ? nil : result
          else
            :continue
          end
        end
      end

      # Add handler for leaf values (non-Hash/Array)
      # Compatible with JsonUtil's value_func
      # @yield [obj, keys, state] handler block for leaf values
      # @return [self] for method chaining
      def add_value_handler(&block)
        add_handler do |obj, keys, state|
          # Only process non-Hash/Array values
          if !obj.is_a?(Hash) && !obj.is_a?(Array)
            block.call(obj, keys, state)
          else
            :continue
          end
        end
      end

      # Add filter to skip elements based on condition
      # @yield [obj, keys, state] condition block (return true to skip)
      # @return [self] for method chaining
      def filter(&condition)
        add_handler do |obj, keys, state|
          condition.call(obj, keys, state) ? nil : :continue
        end
      end

      # Add handler for specific key patterns
      # @param key_pattern [Symbol, String, Regexp] pattern to match
      # @yield [obj, keys, state] handler block for matching keys
      # @return [self] for method chaining
      def for_key(key_pattern, &block)
        add_handler do |obj, keys, state|
          last_key = keys.last
          matches = case key_pattern
          when Symbol, String then last_key == key_pattern
          when Regexp then last_key.to_s =~ key_pattern
          else false
          end

          matches ? block.call(obj, keys, state) : :continue
        end
      end

      # Add handler for specific path patterns
      # @param path_pattern [String, Regexp] path pattern (e.g., "user.email")
      # @yield [obj, keys, state] handler block for matching paths
      # @return [self] for method chaining
      def at_path(path_pattern, &block)
        unless path_pattern.is_a?(String) || path_pattern.is_a?(Regexp)
          raise InvalidPatternError, 'Path pattern must be String or Regexp'
        end
        raise InvalidHandlerError, 'Handler block is required' unless block_given?

        add_handler do |obj, keys, state|
          current_path = keys.map(&:to_s).join('.')
          matches = case path_pattern
          when String then current_path == path_pattern
          when Regexp then current_path =~ path_pattern
          end

          matches ? block.call(obj, keys, state) : :continue
        end
      end

      # Generate JSON and write to file
      # @param obj [Object] object to serialize
      # @param filename [String] output filename
      # @param keys [Array] initial key path (optional)
      def generate_to_file(obj, filename, keys: [])
        File.write(filename, generate(obj, keys: keys))
      end
      # }}}

      # Generate JSON string from object
      # @param obj [Object] object to serialize
      # @param keys [Array] current key path (used internally)
      # @return [String] JSON string
      def generate(obj, keys: [])
        # Execute handler chain
        @handlers.each do |handler|
          result = handler.call(obj, keys, @state)
          return result unless result == :continue
        end

        # Default processing
        if obj.is_a?(Hash)
          hash_to_json(obj, keys)
        elsif obj.is_a?(Array)
          array_to_json(obj, keys)
        else
          obj.to_json(@state)
        end
      end

      private

      attr_reader :state

      # Check if value should be skipped
      def should_skip_value?(value)
        return false unless @skip_nil
        value.nil? || value == nil.to_json(@state)
      end

      # Convert Hash to JSON string
      def hash_to_json(obj, keys) # {{{
        delim = ','
        delim = delim + state.object_nl
        result = StringIO.new
        result << '{'
        result << state.object_nl
        depth = state.depth += 1
        first = true
        indent = !state.object_nl.empty?

        # Sort keys if configured
        entries = @sort_keys ? obj.sort_by { |k, _| k.to_s } : obj

        entries.each do |key, value|
          v = generate(value, keys: keys + [key])
          next if should_skip_value?(v)

          result << delim unless first
          result << state.indent * depth if indent
          result << key.to_s.to_json(state)
          result << state.space_before
          result << ':'
          result << state.space
          result << v
          first = false
        end

        depth = state.depth -= 1
        result << state.object_nl unless first # Avoid empty object with newlines
        result << state.indent * depth if indent
        result << '}'
        result.string
      end # }}}

      # Convert Array to JSON string
      def array_to_json(obj, keys) # {{{
        delim = ','
        delim = delim + state.array_nl
        result = StringIO.new
        result << '['
        result << state.array_nl
        depth = state.depth += 1
        first = true
        indent = !state.array_nl.empty?

        obj.each_with_index do |value, index|
          v = generate(value, keys: keys + [index])
          next if should_skip_value?(v)

          result << delim unless first
          result << state.indent * depth if indent
          result << v
          first = false
        end

        depth = state.depth -= 1
        result << state.array_nl unless first # Avoid empty array with double newlines
        result << state.indent * depth if indent
        result << ']'
        result.string
      end # }}}
    end
  end
end
