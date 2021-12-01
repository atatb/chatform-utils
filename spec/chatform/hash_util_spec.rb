require 'spec_helper'

describe Chatform::Utils::HashUtil do
  subject(:hash_convert) do # rubocop:disable RSpec/MultipleSubjects
    described_class.convert(data, key_func: key_func, value_func: value_func, object_func: object_func)
  end
  subject(:hash_convert_value) do
    described_class.convert_value(data, key_func: key_func, object_func: object_func) do |v, k|
      value_func ? value_func.call(v, k) : v
    end
  end
  let(:data) { raise NotImplementedError }
  let(:key_func) { nil }
  let(:value_func) { nil }
  let(:object_func) { nil }

  context 'with key_func' do
    let!(:expected_to) do
      { KEY: 'value' }
    end
    let(:data) do
      {
        key: 'value'
      }
    end
    let(:key_func) do
      ->(k) { k.upcase }
    end
    it { expect(hash_convert).to eq(expected_to) }
    it { expect(hash_convert_value).to eq(expected_to) }
  end

  context 'with value_func' do
    let!(:expected_to) do
      { key: 'value1', upcase: 'VALUE2' }
    end
    let(:data) do
      {
        key: 'value1',
        upcase: 'value2',
      }
    end
    let(:value_func) do
      ->(v, k) do
        if k == :upcase
          v.upcase
        else
          v
        end
      end
    end
    it { expect(hash_convert).to eq(expected_to) }
    it { expect(hash_convert_value).to eq(expected_to) }
  end

  context 'with object_func' do
    let!(:expected_to) do
      [{ case: 'up', target: 'up' }, { case: 'down', target: 'down' }]
    end
    let(:data) do
      [
        {
          case: 'up',
        },
        {
          case: 'down',
        },
      ]
    end
    let(:object_func) do
      ->(object, _keys = []) do
        if object.is_a?(Hash)
          object[:target] = 'up' if object[:case] == 'up'
          object[:target] = 'down' if object[:case] == 'down'
        end
      end
    end
    it { expect(hash_convert).to eq(expected_to) }
    it { expect(hash_convert_value).to eq(expected_to) }
  end

  context 'with object_func (complex with returning false)' do
    let!(:expected_to) do # {{{
      [
        {
          show: true,
          test: 'aaa',
          # nest1: nil, # NOTE: removed
          nest2: [
            {
              show: true,
            },
          ],
          nest3: [],
        },
        {
          # show: nil, # NOTE: removed
          test: 'bbb',
        },
        {
          test: 'ddd',
        },
        {
          array: [
            'aaa',
            # nil,
            'bbb',
          ],
        },
      ]
    end # }}}
    let(:data) do
      [
        {
          show: true,
          test: 'aaa',
          nest1: {
            show: false,
            test: 'aa2',
          },
          nest2: [
            {
              show: true,
            },
            {
              show: false,
            },
          ],
          nest3: [
            {
              show: false,
            },
          ],
        },
        {
          show: nil,
          test: 'bbb',
        },
        {
          show: false,
          test: 'ccc',
        },
        {
          test: 'ddd',
        },
        {
          array: [
            'aaa',
            nil,
            'bbb',
          ],
        },
      ]
    end
    let(:object_func) do
      ->(object, _keys = []) do
        return object[:show] if object.is_a?(Hash)
      end
    end
    it { expect(hash_convert).to eq(expected_to) }
    it { expect(hash_convert_value).to eq(expected_to) }
  end

  context 'with object_func using keys' do
    let!(:expected_to) do # {{{
      [
        {
          key11: {
            case: 'up',
            target: 'up-key11',
            test: 'none'
          },
          key12: {
            case: 'up',
            target: 'up-key12',
            keys21: {
              case: 'down',
              target: 'down-key12.keys21'
            },
          }
        }
      ]
    end # }}}
    let(:data) do
      [
        key11: {
          case: 'up',
          test: 'none',
        },
        key12: {
          case: 'up',
          keys21: {
            case: 'down',
          },
        },
      ]
    end
    let(:object_func) do
      ->(object, keys = []) do
        if object.is_a?(Hash)
          object[:target] = "up-#{keys.join('.')}" if object[:case] == 'up'
          object[:target] = "down-#{keys.join('.')}" if object[:case] == 'down'
        end
      end
    end
    it { expect(hash_convert).to eq(expected_to) }
    it { expect(hash_convert_value).to eq(expected_to) }
  end

  context 'with all func arguments' do
    let!(:expected_to) do # {{{
      [
        {
          KEY11: {
            CASE: 'up',
            TARGET: 'up-key11',
            TEST: 'none',
          },
          KEY12: {
            CASE: 'up',
            TARGET: 'up-key12',
            KEYS21: {
              CASE: 'down',
              TARGET: 'down-key12.keys21',
              UPCASE: 'VALUE',
            },
          },
        }
      ]
    end # }}}
    let(:data) do
      [
        key11: {
          case: 'up',
          test: 'none',
        },
        key12: {
          case: 'up',
          keys21: {
            case: 'down',
            upcase: 'value',
          },
        },
      ]
    end
    let(:key_func) do
      ->(k) { k.upcase }
    end
    let(:value_func) do
      ->(v, k) do
        if k == :upcase # keys have original key (not upper by key_func)
          v.upcase
        else
          v
        end
      end
    end
    let(:object_func) do
      ->(object, keys = []) do
        if object.is_a?(Hash)
          object[:target] = "up-#{keys.join('.')}" if object[:case] == 'up'
          object[:target] = "down-#{keys.join('.')}" if object[:case] == 'down'
        end
      end
    end
    it { expect(hash_convert).to eq(expected_to) }
    it { expect(hash_convert_value { |v, k| value_func.call(v, k) }).to eq(expected_to) }
  end
end
