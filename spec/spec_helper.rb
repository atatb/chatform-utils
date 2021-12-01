# frozen_string_literal: true

require 'chatform/utils'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  # Call RSpec.describe instead of just describe.
  # https://stackoverflow.com/questions/26987517/rspec-nomethoderror-undefined-method-describe-for-main-object
  config.expose_dsl_globally = true

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
