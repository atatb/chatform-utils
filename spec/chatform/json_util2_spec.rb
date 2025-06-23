require 'spec_helper'
require 'fileutils'

describe Chatform::Utils::JsonUtil2 do
  describe '.new' do
    context 'with pretty format' do
      subject { described_class.new(format: :pretty) }
      
      it 'generates pretty formatted JSON' do
        data = { key: 'value', nested: { foo: 'bar' } }
        result = subject.generate(data)
        expected = "{\n  \"key\": \"value\",\n  \"nested\": {\n    \"foo\": \"bar\"\n  }\n}"
        expect(result).to eq(expected)
      end
    end

    context 'with compact format' do
      subject { described_class.new(format: :compact) }
      
      it 'generates compact formatted JSON' do
        data = { key: 'value', nested: { foo: 'bar' } }
        result = subject.generate(data)
        expected = '{"key":"value","nested":{"foo":"bar"}}'
        expect(result).to eq(expected)
      end
    end

    context 'with custom format Hash' do
      subject { described_class.new(format: { indent: '    ', space: ' ', space_before: '', object_nl: "\n", array_nl: "\n" }) }
      
      it 'generates JSON with custom formatting' do
        data = { key: 'value' }
        result = subject.generate(data)
        expected = "{\n    \"key\": \"value\"\n}"
        expect(result).to eq(expected)
      end
    end

    context 'with invalid format' do
      it 'raises ArgumentError' do
        expect { described_class.new(format: :invalid) }.to raise_error(ArgumentError, /Invalid format/)
      end
    end

    context 'with skip_nil option' do
      context 'when skip_nil is true (default)' do
        subject { described_class.new(skip_nil: true) }
        
        it 'skips nil values in hashes' do
          data = { key1: 'value', key2: nil, key3: 'another' }
          result = subject.generate(data)
          expect(result).not_to include('key2')
          expect(result).not_to include('null')
        end

        it 'skips nil values in arrays' do
          data = { items: ['first', nil, 'third'] }
          result = subject.generate(data)
          expect(result).not_to include('null')
        end
      end

      context 'when skip_nil is false' do
        subject { described_class.new(skip_nil: false) }
        
        it 'includes nil values in hashes' do
          data = { key1: 'value', key2: nil }
          result = subject.generate(data)
          expect(result).to include('"key2": null')
        end

        it 'includes nil values in arrays' do
          data = { items: ['first', nil, 'third'] }
          result = subject.generate(data)
          expect(result).to include('null')
        end
      end
    end

    context 'with sort_keys option' do
      context 'when sort_keys is true' do
        subject { described_class.new(sort_keys: true) }
        
        it 'sorts hash keys alphabetically' do
          data = { zebra: 1, apple: 2, mango: 3 }
          result = subject.generate(data)
          # Check the order of keys in the output
          apple_pos = result.index('"apple"')
          mango_pos = result.index('"mango"')
          zebra_pos = result.index('"zebra"')
          expect(apple_pos).to be < mango_pos
          expect(mango_pos).to be < zebra_pos
        end
      end

      context 'when sort_keys is false (default)' do
        subject { described_class.new(sort_keys: false) }
        
        it 'maintains original key order' do
          data = { zebra: 1, apple: 2, mango: 3 }
          result = subject.generate(data)
          # Keys should appear in insertion order
          zebra_pos = result.index('"zebra"')
          apple_pos = result.index('"apple"')
          mango_pos = result.index('"mango"')
          expect(zebra_pos).to be < apple_pos
          expect(apple_pos).to be < mango_pos
        end
      end
    end
  end

  describe '.pretty' do
    it 'creates instance with pretty format' do
      data = { key: 'value' }
      result = described_class.pretty.generate(data)
      expect(result).to eq("{\n  \"key\": \"value\"\n}")
    end

    it 'accepts skip_nil and sort_keys options' do
      util = described_class.pretty(skip_nil: false, sort_keys: true)
      expect(util.skip_nil).to eq(false)
      expect(util.sort_keys).to eq(true)
    end
  end

  describe '.compact' do
    it 'creates instance with compact format' do
      data = { key: 'value' }
      result = described_class.compact.generate(data)
      expect(result).to eq('{"key":"value"}')
    end

    it 'accepts skip_nil and sort_keys options' do
      util = described_class.compact(skip_nil: false, sort_keys: true)
      expect(util.skip_nil).to eq(false)
      expect(util.sort_keys).to eq(true)
    end
  end

  describe '.with_options' do
    it 'creates instance with custom options' do
      opts = { indent: '    ', space: ' ', space_before: '', object_nl: "\n", array_nl: "\n" }
      util = described_class.with_options(opts)
      data = { key: 'value' }
      result = util.generate(data)
      expect(result).to include('    ')
    end

    it 'raises ArgumentError for non-Hash options' do
      expect { described_class.with_options('invalid') }.to raise_error(Chatform::Utils::InvalidPatternError, 'Options must be a Hash')
    end
  end

  describe '#add_handler' do
    subject { described_class.pretty }
    
    it 'adds custom handler' do
      subject.add_handler do |obj, keys, state|
        if obj.is_a?(String) && keys.last == :special
          '"SPECIAL: ' + obj + '"'
        else
          :continue
        end
      end
      
      data = { normal: 'value', special: 'value' }
      result = subject.generate(data)
      expect(result).to include('"SPECIAL: value"')
      expect(result).to include('"normal": "value"')
    end

    it 'supports method chaining' do
      result = subject.add_handler { :continue }
      expect(result).to eq(subject)
    end

    it 'raises error when no block given' do
      expect { subject.add_handler }.to raise_error(Chatform::Utils::InvalidHandlerError, 'Handler block is required')
    end
  end

  describe '#clear_handlers' do
    subject { described_class.pretty }
    
    it 'removes all handlers' do
      subject.add_handler { '"modified"' }
      expect(subject.handler_count).to eq(1)
      
      subject.clear_handlers
      expect(subject.handler_count).to eq(0)
      
      # Should use default behavior after clearing
      result = subject.generate('test')
      expect(result).to eq('"test"')
    end

    it 'supports method chaining' do
      result = subject.clear_handlers
      expect(result).to eq(subject)
    end
  end

  describe '#handler_count' do
    subject { described_class.pretty }
    
    it 'returns the number of handlers' do
      expect(subject.handler_count).to eq(0)
      
      subject.add_handler { :continue }
      expect(subject.handler_count).to eq(1)
      
      subject.add_handler { :continue }
      expect(subject.handler_count).to eq(2)
    end
  end

  describe '#handle_type' do
    subject { described_class.pretty }
    
    it 'handles specific types' do
      subject.handle_type(String) do |obj, keys, state|
        '"String: ' + obj + '"'
      end
      
      data = { text: 'hello', number: 42 }
      result = subject.generate(data)
      expect(result).to include('"String: hello"')
      expect(result).to include('42') # Number unchanged
    end

    it 'skips elements when handler returns nil' do
      subject.handle_type(String) do |obj, keys, state|
        nil
      end
      
      data = { text: 'hello', number: 42 }
      result = subject.generate(data)
      expect(result).not_to include('hello')
      expect(result).to include('42')
    end

    it 'raises error for invalid type' do
      expect { subject.handle_type('not a class') {} }.to raise_error(Chatform::Utils::InvalidPatternError, 'Type must be a Class or Module')
    end

    it 'raises error when no block given' do
      expect { subject.handle_type(String) }.to raise_error(Chatform::Utils::InvalidHandlerError)
    end
  end

  describe '#add_value_handler' do
    subject { described_class.pretty }
    
    it 'only processes leaf values' do
      subject.add_value_handler do |obj, keys, state|
        if obj.is_a?(String)
          (obj.upcase).to_json(state)
        else
          obj.to_json(state)
        end
      end
      
      data = {
        text: 'hello',
        nested: { inner: 'world' },
        array: ['foo', 'bar']
      }
      result = subject.generate(data)
      expect(result).to include('"HELLO"')
      expect(result).to include('"WORLD"')
      expect(result).to include('"FOO"')
      expect(result).to include('"BAR"')
    end
  end

  describe '#filter' do
    subject { described_class.pretty }
    
    it 'filters out elements based on condition' do
      # Filter should check the last key, not the value
      subject.filter do |obj, keys, state|
        last_key = keys.last
        last_key && last_key.to_s.start_with?('_')
      end
      
      data = {
        public: 'visible',
        _private: 'hidden',
        nested: { _secret: 'hidden', normal: 'visible' }
      }
      result = subject.generate(data)
      expect(result).to include('visible')
      expect(result).not_to include('hidden')
      expect(result).not_to include('_private')
      expect(result).not_to include('_secret')
    end
  end

  describe '#for_key' do
    subject { described_class.pretty }
    
    it 'handles specific key names' do
      subject.for_key(:password) do |obj, keys, state|
        '"***"'
      end
      
      data = {
        username: 'john',
        password: 'secret123',
        nested: { password: 'another_secret' }
      }
      result = subject.generate(data)
      expect(result).to include('"username": "john"')
      expect(result).to include('"password": "***"')
      expect(result.scan('"***"').count).to eq(2)
    end

    it 'handles regex patterns' do
      subject.for_key(/^_/) do |obj, keys, state|
        nil # Skip private keys
      end
      
      data = { public: 'visible', _private: 'hidden' }
      result = subject.generate(data)
      expect(result).to include('visible')
      expect(result).not_to include('hidden')
    end
  end

  describe '#at_path' do
    subject { described_class.pretty }
    
    it 'handles specific paths' do
      subject.at_path('user.email') do |obj, keys, state|
        '"[REDACTED]"'
      end
      
      data = {
        user: {
          name: 'John',
          email: 'john@example.com'
        },
        email: 'admin@example.com'
      }
      result = subject.generate(data)
      expect(result).to include('"[REDACTED]"')
      expect(result).to include('"admin@example.com"') # Top-level email unchanged
    end

    it 'handles regex patterns' do
      subject.at_path(/\.password$/) do |obj, keys, state|
        '"***"'
      end
      
      data = {
        user: { password: 'secret' },
        admin: { password: 'topsecret' },
        password: 'unchanged'
      }
      result = subject.generate(data)
      expect(result.scan('"***"').count).to eq(2)
      expect(result).to include('"unchanged"')
    end

    it 'raises error for invalid pattern' do
      expect { subject.at_path(123) {} }.to raise_error(Chatform::Utils::InvalidPatternError)
    end

    it 'raises error when no block given' do
      expect { subject.at_path('test.path') }.to raise_error(Chatform::Utils::InvalidHandlerError)
    end
  end

  describe '#generate_to_file' do
    subject { described_class.pretty }
    let(:temp_file) { 'tmp/test_output.json' }
    
    before do
      FileUtils.mkdir_p('tmp')
    end
    
    after do
      FileUtils.rm_f(temp_file)
    end
    
    it 'writes JSON to file' do
      data = { key: 'value' }
      subject.generate_to_file(data, temp_file)
      
      expect(File.exist?(temp_file)).to be true
      content = File.read(temp_file)
      expect(content).to eq("{\n  \"key\": \"value\"\n}")
    end
  end

  describe '#generate' do
    subject { described_class.pretty }
    
    context 'with complex nested structures' do
      it 'handles deep nesting' do
        data = {
          level1: {
            level2: {
              level3: {
                level4: 'deep value'
              }
            }
          }
        }
        result = subject.generate(data)
        expect(result).to include('"level4": "deep value"')
        expect(result.count("\n")).to be > 5 # Multiple newlines for formatting
      end
    end

    context 'with special characters' do
      it 'escapes JSON special characters' do
        data = {
          quotes: 'He said "Hello"',
          backslash: 'C:\\Users\\test',
          newline: "Line 1\nLine 2",
          tab: "Col1\tCol2"
        }
        result = subject.generate(data)
        parsed = JSON.parse(result)
        expect(parsed['quotes']).to eq('He said "Hello"')
        expect(parsed['backslash']).to eq('C:\\Users\\test')
        expect(parsed['newline']).to eq("Line 1\nLine 2")
        expect(parsed['tab']).to eq("Col1\tCol2")
      end
    end

    context 'with empty collections' do
      it 'handles empty hash' do
        result = subject.generate({})
        expect(result).to eq("{\n}")
      end

      it 'handles empty array' do
        result = subject.generate([])
        expect(result).to eq("[\n]")
      end
    end

    context 'with handler chain' do
      it 'executes handlers in order' do
        subject
          .add_handler do |obj, keys, state|
            if obj == 'first'
              '"FIRST"'
            else
              :continue
            end
          end
          .add_handler do |obj, keys, state|
            if obj == 'second'
              '"SECOND"'
            else
              :continue
            end
          end
        
        data = { a: 'first', b: 'second', c: 'third' }
        result = subject.generate(data)
        expect(result).to include('"FIRST"')
        expect(result).to include('"SECOND"')
        expect(result).to include('"third"')
      end
    end
  end

  describe 'StringIO performance optimization' do
    it 'uses StringIO for better performance' do
      # This is more of an implementation detail test
      # We verify it works correctly with large data
      subject = described_class.pretty
      large_data = {}
      1000.times { |i| large_data["key_#{i}"] = "value_#{i}" }
      
      result = subject.generate(large_data)
      parsed = JSON.parse(result)
      expect(parsed.size).to eq(1000)
    end
  end
end