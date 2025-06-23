require 'spec_helper'

describe Chatform::Utils::HashUtil2 do
  describe '.new' do
    context 'with default options' do
      subject { described_class.new }
      
      it 'does not skip nil values by default' do
        data = { key: 'value', nil_key: nil }
        result = subject.transform(data)
        expect(result).to eq({ key: 'value', nil_key: nil })
      end
    end

    context 'with skip_nil option' do
      subject { described_class.new(skip_nil: true) }
      
      it 'skips nil values when enabled' do
        data = { key: 'value', nil_key: nil }
        result = subject.transform(data)
        expect(result).to eq({ key: 'value' })
      end
    end
  end

  describe '.new_transformer' do
    it 'creates instance with options' do
      transformer = described_class.new_transformer(skip_nil: true)
      expect(transformer.skip_nil).to eq(true)
    end
  end

  describe '#add_handler' do
    subject { described_class.new }
    
    it 'adds custom handler' do
      subject.add_handler do |obj, keys, parent|
        if obj.is_a?(String) && keys.last == :upper
          obj.upcase
        else
          :continue
        end
      end
      
      data = { upper: 'hello', normal: 'world' }
      result = subject.transform(data)
      expect(result).to eq({ upper: 'HELLO', normal: 'world' })
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
    subject { described_class.new }
    
    it 'removes all handlers' do
      subject.add_handler { 'modified' }
      expect(subject.handler_count).to eq(1)
      
      subject.clear_handlers
      expect(subject.handler_count).to eq(0)
      
      # Should use default behavior after clearing
      result = subject.transform('test')
      expect(result).to eq('test')
    end

    it 'supports method chaining' do
      result = subject.clear_handlers
      expect(result).to eq(subject)
    end
  end

  describe '#handler_count' do
    subject { described_class.new }
    
    it 'returns the number of handlers' do
      expect(subject.handler_count).to eq(0)
      
      subject.add_handler { :continue }
      expect(subject.handler_count).to eq(1)
      
      subject.add_handler { :continue }
      expect(subject.handler_count).to eq(2)
    end
  end

  describe '#handle_type' do
    subject { described_class.new }
    
    it 'handles specific types' do
      subject.handle_type(String) do |obj, keys, parent|
        "String: #{obj}"
      end
      
      data = { text: 'hello', number: 42 }
      result = subject.transform(data)
      expect(result).to eq({ text: 'String: hello', number: 42 })
    end

    it 'skips elements when handler returns nil' do
      subject.handle_type(String) { nil }
      
      data = { text: 'hello', number: 42 }
      result = subject.transform(data)
      expect(result).to eq({ text: nil, number: 42 })
    end

    it 'raises error for invalid type' do
      expect { subject.handle_type('not a class') {} }.to raise_error(Chatform::Utils::InvalidPatternError, 'Type must be a Class or Module')
    end

    it 'raises error when no block given' do
      expect { subject.handle_type(String) }.to raise_error(Chatform::Utils::InvalidHandlerError)
    end
  end

  describe '#add_value_handler' do
    subject { described_class.new }
    
    it 'only processes leaf values' do
      subject.add_value_handler do |obj, keys, parent|
        obj.is_a?(String) ? obj.upcase : obj
      end
      
      data = {
        text: 'hello',
        nested: { inner: 'world' },
        array: ['foo', 'bar']
      }
      result = subject.transform(data)
      expect(result).to eq({
        text: 'HELLO',
        nested: { inner: 'WORLD' },
        array: ['FOO', 'BAR']
      })
    end
  end

  describe '#filter' do
    subject { described_class.new(skip_nil: true) }
    
    it 'filters out elements based on condition' do
      # Filter out private keys (starting with _)
      subject.filter do |obj, keys, parent|
        last_key = keys.last
        last_key && last_key.to_s.start_with?('_')
      end
      
      data = {
        public: 'visible',
        _private: 'hidden',
        nested: { _secret: 'hidden', normal: 'visible' }
      }
      result = subject.transform(data)
      expect(result).to eq({
        public: 'visible',
        nested: { normal: 'visible' }
      })
    end
  end

  describe '#for_key' do
    subject { described_class.new }
    
    it 'handles specific key names' do
      subject.for_key(:password) do |obj, keys, parent|
        '***'
      end
      
      data = {
        username: 'john',
        password: 'secret123',
        nested: { password: 'another_secret' }
      }
      result = subject.transform(data)
      expect(result).to eq({
        username: 'john',
        password: '***',
        nested: { password: '***' }
      })
    end

    it 'handles regex patterns' do
      subject.for_key(/^temp_/) do |obj, keys, parent|
        nil # Remove temporary keys
      end
      
      data = { temp_file: 'file.tmp', real_file: 'file.txt', temp_data: 'data' }
      result = subject.transform(data)
      expect(result).to eq({ temp_file: nil, real_file: 'file.txt', temp_data: nil })
    end
  end

  describe '#at_path' do
    subject { described_class.new }
    
    it 'handles specific paths' do
      subject.at_path('user.email') do |obj, keys, parent|
        '[REDACTED]'
      end
      
      data = {
        user: {
          name: 'John',
          email: 'john@example.com'
        },
        email: 'admin@example.com'
      }
      result = subject.transform(data)
      expect(result).to eq({
        user: {
          name: 'John',
          email: '[REDACTED]'
        },
        email: 'admin@example.com'
      })
    end

    it 'handles regex patterns' do
      subject.at_path(/\.password$/) do |obj, keys, parent|
        '***'
      end
      
      data = {
        user: { password: 'secret' },
        admin: { password: 'topsecret' },
        password: 'unchanged'
      }
      result = subject.transform(data)
      expect(result).to eq({
        user: { password: '***' },
        admin: { password: '***' },
        password: 'unchanged'
      })
    end

    it 'raises error for invalid pattern' do
      expect { subject.at_path(123) {} }.to raise_error(Chatform::Utils::InvalidPatternError)
    end

    it 'raises error when no block given' do
      expect { subject.at_path('test.path') }.to raise_error(Chatform::Utils::InvalidHandlerError)
    end
  end

  describe '#transform' do
    subject { described_class.new }
    
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
        result = subject.transform(data)
        expect(result).to eq(data)
      end
    end

    context 'with arrays' do
      it 'transforms array elements' do
        subject.add_value_handler do |obj, keys, parent|
          obj.is_a?(String) ? obj.upcase : obj
        end
        
        data = { items: ['a', 'b', 'c'] }
        result = subject.transform(data)
        expect(result).to eq({ items: ['A', 'B', 'C'] })
      end

      it 'handles arrays with mixed types' do
        data = { items: ['string', 123, true, nil, { nested: 'value' }] }
        result = subject.transform(data)
        expect(result).to eq(data)
      end
    end

    context 'with handler chain' do
      it 'executes handlers in order' do
        subject
          .add_handler do |obj, keys, state|
            if obj == 'first'
              'FIRST'
            else
              :continue
            end
          end
          .add_handler do |obj, keys, state|
            if obj == 'second'
              'SECOND'
            else
              :continue
            end
          end
        
        data = { a: 'first', b: 'second', c: 'third' }
        result = subject.transform(data)
        expect(result).to eq({ a: 'FIRST', b: 'SECOND', c: 'third' })
      end

      it 'stops at first handler that returns non-:continue' do
        subject
          .add_handler do |obj, keys, state|
            obj.is_a?(String) ? 'REPLACED' : :continue
          end
          .add_handler do |obj, keys, state|
            obj.is_a?(String) ? 'NEVER_REACHED' : :continue
          end
        
        data = { key: 'value' }
        result = subject.transform(data)
        expect(result).to eq({ key: 'REPLACED' })
      end
    end

    context 'with skip_nil' do
      subject { described_class.new(skip_nil: true) }
      
      it 'removes nil values from hashes' do
        data = { a: 1, b: nil, c: 3 }
        result = subject.transform(data)
        expect(result).to eq({ a: 1, c: 3 })
      end

      it 'removes nil values from arrays' do
        data = { items: [1, nil, 3] }
        result = subject.transform(data)
        expect(result).to eq({ items: [1, 3] })
      end
    end
  end

  describe 'compatibility with HashUtil' do
    it 'can replicate HashUtil convert_key behavior' do
      util2 = described_class.new
      util2.add_handler do |obj, keys, parent|
        if obj.is_a?(Hash)
          # Transform keys and recursively process the hash
          transformed = {}
          obj.each do |k, v|
            transformed[k.to_s] = util2.transform(v, keys + [k], obj)
          end
          transformed
        else
          :continue
        end
      end
      
      data = { key: 'value', nested: { foo: 'bar' } }
      result = util2.transform(data)
      expect(result).to eq({ 'key' => 'value', 'nested' => { 'foo' => 'bar' } })
    end

    it 'can replicate HashUtil convert_value behavior' do
      util2 = described_class.new
      util2.add_value_handler do |obj, keys, parent|
        obj.to_s
      end
      
      data = { string: 'hello', number: 42, bool: true }
      result = util2.transform(data)
      expect(result).to eq({ string: 'hello', number: '42', bool: 'true' })
    end

    it 'can replicate HashUtil convert_object behavior' do
      util2 = described_class.new(skip_nil: true)
      util2.filter do |obj, keys, parent|
        obj.is_a?(Hash) && obj[:skip] == true
      end
      
      data = [
        { name: 'show', skip: false },
        { name: 'hide', skip: true },
        { name: 'show2' }
      ]
      result = util2.transform(data)
      expect(result).to eq([
        { name: 'show', skip: false },
        { name: 'show2' }
      ])
    end
  end
end