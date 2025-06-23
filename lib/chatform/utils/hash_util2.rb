# frozen_string_literal: true

module Chatform
  module Utils
    # Enhanced Hash transformation utility with handler chain pattern
    class HashUtil2
      attr_reader :skip_nil

      # Initialize transformer
      # @param skip_nil [Boolean] whether to skip nil values (default: false)
      def initialize(skip_nil: false)
        @handlers = []
        @skip_nil = skip_nil
      end

      # Factory method
      def self.new_transformer(skip_nil: false)
        new(skip_nil: skip_nil)
      end

      # Add a handler to the processing chain
      # @yield [obj, keys, parent] handler block
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
      # @yield [obj, keys, parent] handler block for matching objects
      # @return [self] for method chaining
      def handle_type(type, &block)
        raise InvalidPatternError, 'Type must be a Class or Module' unless type.is_a?(Class) || type.is_a?(Module)
        raise InvalidHandlerError, 'Handler block is required' unless block_given?
        
        add_handler do |obj, keys, parent|
          if obj.is_a?(type)
            result = block.call(obj, keys, parent)
            # Return nil to skip the element
            result.nil? ? nil : result
          else
            :continue
          end
        end
      end

      # Add handler for leaf values (non-Hash/Array)
      # @yield [obj, keys, parent] handler block for leaf values
      # @return [self] for method chaining
      def add_value_handler(&block)
        add_handler do |obj, keys, parent|
          # Only process non-Hash/Array values
          if !obj.is_a?(Hash) && !obj.is_a?(Array)
            block.call(obj, keys, parent)
          else
            :continue
          end
        end
      end

      # Add filter to skip elements based on condition
      # @yield [obj, keys, parent] condition block (return true to skip)
      # @return [self] for method chaining
      def filter(&condition)
        add_handler do |obj, keys, parent|
          condition.call(obj, keys, parent) ? nil : :continue
        end
      end

      # Add handler for specific key patterns
      # @param key_pattern [Symbol, String, Regexp] pattern to match
      # @yield [obj, keys, parent] handler block for matching keys
      # @return [self] for method chaining
      def for_key(key_pattern, &block)
        add_handler do |obj, keys, parent|
          last_key = keys.last
          matches = case key_pattern
          when Symbol, String then last_key == key_pattern
          when Regexp then last_key.to_s =~ key_pattern
          else false
          end

          matches ? block.call(obj, keys, parent) : :continue
        end
      end

      # Add handler for specific path patterns
      # @param path_pattern [String, Regexp] path pattern (e.g., "user.email")
      # @yield [obj, keys, parent] handler block for matching paths
      # @return [self] for method chaining
      def at_path(path_pattern, &block)
        unless path_pattern.is_a?(String) || path_pattern.is_a?(Regexp)
          raise InvalidPatternError, 'Path pattern must be String or Regexp'
        end
        raise InvalidHandlerError, 'Handler block is required' unless block_given?
        
        add_handler do |obj, keys, parent|
          current_path = keys.map(&:to_s).join('.')
          matches = case path_pattern
          when String then current_path == path_pattern
          when Regexp then current_path =~ path_pattern
          end

          matches ? block.call(obj, keys, parent) : :continue
        end
      end
      # }}}

      # Transform object with registered handlers
      # @param obj [Object] object to transform
      # @param keys [Array] current key path (used internally)
      # @return [Object] transformed object
      def transform(obj, keys = [], parent = nil)
        # Execute handler chain
        @handlers.each do |handler|
          result = handler.call(obj, keys, parent)
          return result unless result == :continue
        end

        # Default processing
        if obj.is_a?(Hash)
          hash_transform(obj, keys)
        elsif obj.is_a?(Array)
          array_transform(obj, keys)
        else
          obj
        end
      end

      private

      def hash_transform(obj, keys)
        result = {}
        obj.each do |k, v|
          value = transform(v, keys + [k], obj)
          next if value.nil? && @skip_nil
          result[k] = value
        end
        result
      end

      def array_transform(obj, keys)
        result = []
        obj.each_with_index do |v, i|
          value = transform(v, keys + [i], obj)
          next if value.nil? && @skip_nil
          result << value
        end
        result
      end
    end
  end
end