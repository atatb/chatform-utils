# frozen_string_literal: true
require 'json'

module Chatform
  module Utils
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

      def initialize(format: :pretty)
        @handlers = []
        @state = JSON.state.new(
          format == :compact ? COMPACT_STATE_PROTOTYPE : PRETTY_STATE_PROTOTYPE
        )
      end

      # カスタムオプションで初期化
      def self.with_options(opts)
        instance = allocate
        instance.instance_variable_set(:@handlers, [])
        instance.instance_variable_set(:@state, JSON.state.new(opts))
        instance
      end

      # プリセット
      def self.pretty
        new(format: :pretty)
      end

      def self.compact
        new(format: :compact)
      end

      # ハンドラーを追加（チェーン可能）
      def add_handler(&block)
        @handlers << block
        self
      end

      # Helper method {{{
      # 型別ハンドラー
      def handle_type(type, &block)
        add_handler do |obj, keys, state|
          if obj.is_a?(type)
            result = block.call(obj, keys, state)
            # blockがnilを返した場合は要素をスキップ
            result.nil? ? nil : result
          else
            :continue
          end
        end
      end

      # value_func互換のハンドラーを追加
      def add_value_handler(&block)
        add_handler do |obj, keys, state|
          # Hash/Array以外の場合のみblockを実行
          if !obj.is_a?(Hash) && !obj.is_a?(Array)
            block.call(obj, keys, state)
          else
            :continue
          end
        end
      end

      # 条件付きフィルタ
      def filter(&condition)
        add_handler do |obj, keys, state|
          condition.call(obj, keys, state) ? nil : :continue
        end
      end

      # キーベースのハンドラー
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

      # パスベースのハンドラー
      def at_path(path_pattern, &block)
        add_handler do |obj, keys, state|
          current_path = keys.map(&:to_s).join('.')
          matches = case path_pattern
          when String then current_path == path_pattern
          when Regexp then current_path =~ path_pattern
          else false
          end

          matches ? block.call(obj, keys, state) : :continue
        end
      end
      # }}}

      # Ref: https://github.com/flori/json/blob/master/lib/json/pure/generator.rb
      # https://github.com/ruby/json/blob/master/lib/json/truffle_ruby/generator.rb#L328
      def generate(obj, keys: [])
        # ハンドラーチェーンを実行
        @handlers.each do |handler|
          result = handler.call(obj, keys, @state)
          return result unless result == :continue
        end

        # デフォルト処理
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

        obj.each_with_index do |value, index|
          v = generate(value, keys: keys + [index])
          next if v.nil? || v == nil.to_json(state)

          result << delim unless first
          result << state.indent * depth if indent
          result << v
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
