require 'spec_helper'

def _replace_template_js(js_template) # {{{
  resutls_ = []
  js_template.split("\n").each do |line|
    hit = false
    Chatform::Utils::JsonUtil::JS_KEYS.map { |k| %("#{k}") }.each do |target|
      next unless line.include?(target) && line.include?('=>') # /^\s*(async)?\s*\((\{[a-zA-Z0-9_\s,]+\})?\)\s*=>\s*\{.*\}.*/
      # line #=> "            \"onLoad\": \"() => {\\r\\n  $('#chat-hidden')...
      splits = line.split("#{target}: ") #=> ["            ", "\"() => {\\r\\n  $('#chat-hidden')...]
      remove_first_end = splits.last[1..-2]
      if remove_first_end[-1] == ','
        remove_first_end = remove_first_end[0..-2] # .gsub('\"', '"')
      end
      if remove_first_end[-1] == '"'
        remove_first_end = remove_first_end[0..-2] # .gsub('\"', '"')
      end
      remove_first_end = remove_first_end.gsub('\"', '"')
      line = "#{splits.first}#{target}: #{remove_first_end}"
      hit = true
      break
    end
    resutls_ << if hit
                  # '\\r\\n' : JSON data new line from html form data
                  # '\n'     : JSON source new line from template (seed data)
                  # '\r\n'   : JSON source new line from html form data
                  line.gsub('\\r\\n', "\n").gsub('\r\n', "\n").gsub('\n', "\n")
                else
                  line.gsub('\r\n', '')
                end
  end
  resutls_.join("\n")
end # }}}

module Chatform::Utils
  class JsonUtil
    JS_KEYS = %w[
          onLoad
          onInput
          onChange
          onUpdate
          onClick
          onUpdateValidation
          onValidation
          onValue
          onCondition
    ].freeze
    class << self
      def pretty_generate(object)
        value_func = ->(v, keys, state) {
          if JS_KEYS.include?(keys.last.to_s) && v.include?('=>') # onValue is either function or plain text
            v || v.to_json(state)
          else
            # %("#{String(value)}")
            v.to_json(state)
          end
        }

        object_func = ->(obj, _keys, _state) {
          return obj[:schema_enabled] if obj.is_a?(Hash)
        }
        JsonUtil.generate(object, opts: PRETTY_STATE_PROTOTYPE, value_func: value_func, object_func: object_func)
      end
    end
  end
end

describe Chatform::Utils::JsonUtil do
  subject(:json_pretty_generate) do
    described_class.pretty_generate(data)
  end

  context 'without js code' do
    let(:data) do
      {
        key: 'value',
      }
    end
    it { expect(json_pretty_generate).to eq "{\n  \"key\": \"value\"\n}" }
    it { expect(json_pretty_generate).to eq JSON.pretty_generate(data) }
  end

  context 'with js code' do
    let(:data) do
      {
        onLoad: '() => {}',
      }
    end
    it { expect(json_pretty_generate).to eq "{\n  \"onLoad\": () => {}\n}" }
    it { expect(json_pretty_generate).not_to eq JSON.pretty_generate(data) }

    it 'equals to json data replaced JS code manually' do
      json = JSON.pretty_generate(data)
      replaced_json = _replace_template_js(json)
      expect(json_pretty_generate).to eq replaced_json
    end
  end

  context 'with js code without `() => `' do
    let(:data) do
      {
        onUpdate: 'console.log()',
      }
    end
    it { expect(json_pretty_generate).to eq "{\n  \"onUpdate\": \"console.log()\"\n}" }
    it { expect(json_pretty_generate).to eq JSON.pretty_generate(data) }

    it 'equals to json data replaced JS code manually' do
      json = JSON.pretty_generate(data)
      replaced_json = _replace_template_js(json)
      # "onUpdate": "console.log()"
      expect(json_pretty_generate).to eq replaced_json # <- needs `() => ` besides specific keys for JS codes
    end
  end

  context 'with js code without tailing comma' do
    let(:data) do
      {
        onLoad: '() => {}',
        onUpdate: '() => { console.log() }',
      }
    end
    it { expect(json_pretty_generate).to eq "{\n  \"onLoad\": () => {},\n  \"onUpdate\": () => { console.log() }\n}" }
    it { expect(json_pretty_generate).not_to eq JSON.pretty_generate(data) }

    it 'equals to json data replaced JS code manually' do
      json = JSON.pretty_generate(data)
      replaced_json = _replace_template_js(json)
      # "onLoad": () => {}
      # "onUpdate": () => { console.log() }
      expect(json_pretty_generate).not_to eq replaced_json # <- needs a tailing comma
    end
  end

  context 'with schema_enabled' do
    let(:data) do
      [
        {
          test1: 'aaa',
        },
        {
          schema_enabled: false,
          test2: 'bbb',
        },
        {
          schema_enabled: true,
          test3: 'ccc',
        },
      ]
    end
    let(:expected_to) do
      JSON.pretty_generate(
        [
          {
            test1: 'aaa',
          },
          # hash with schema_enabled: false is ignored
          {
            schema_enabled: true,
            test3: 'ccc',
          },
        ]
      )
    end
    it { expect(json_pretty_generate).to eq(expected_to) }
  end

  context 'with schema_enabled (complex)' do
    let(:expected_to) do
      [
        {
          schema_enabled: true,
          test: 'aaa',
          # nest1: nil, # NOTE: removed
          nest2: [
            {
              schema_enabled: true,
            },
          ],
          nest3: [],
        },
        {
          # schema_enabled: nil, # NOTE: `v == nil.to_json(state)` in JsonUtilClass.hash_to_json
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
    end
    let(:data) do
      [
        {
          schema_enabled: true,
          test: 'aaa',
          nest1: {
            schema_enabled: false,
            test: 'aa2',
          },
          nest2: [
            {
              schema_enabled: true,
            },
            {
              schema_enabled: false,
            },
          ],
          nest3: [
            {
              schema_enabled: false,
            },
          ],
        },
        {
          schema_enabled: nil,
          test: 'bbb',
        },
        {
          schema_enabled: false,
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
    it { expect(json_pretty_generate).to eq(JSON.pretty_generate(expected_to)) }
    it { expect(described_class.pretty_generate(expected_to)).to eq(JSON.pretty_generate(expected_to)) }
  end
end
