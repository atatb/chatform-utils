# frozen_string_literal: true

module Chatform
  module Utils
    class Error < StandardError; end
    class InvalidHandlerError < Error; end
    class InvalidPatternError < Error; end
  end
end

require_relative 'utils/version'
require_relative 'utils/hash_util'
require_relative 'utils/hash_util2'
require_relative 'utils/json_util'
require_relative 'utils/json_util2'
