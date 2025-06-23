# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Development Commands

### Setup and Dependencies
```bash
# Install dependencies
bundle install

# Or use the setup script
bin/setup

# Interactive console with the gem loaded
bin/console
```

### Testing
```bash
# Run all tests (default rake task)
rake
# or
bundle exec rspec

# Run specific test file
bundle exec rspec spec/chatform/hash_util_spec.rb
bundle exec rspec spec/chatform/hash_util2_spec.rb
bundle exec rspec spec/chatform/json_util_spec.rb
bundle exec rspec spec/chatform/json_util2_spec.rb

# Run a specific test by line number
bundle exec rspec spec/chatform/json_util2_spec.rb:123

# Run tests matching a pattern
bundle exec rspec -e "with pretty format"
```

### Building and Releasing
```bash
# Build the gem into pkg/ directory
bundle exec rake build

# Install gem to local system
bundle exec rake install

# Release new version (updates version, creates git tag, pushes to rubygems)
bundle exec rake release

# Generate checksums
bundle exec rake build:checksum

# Clean build artifacts
bundle exec rake clean
bundle exec rake clobber
```

### Code Quality
```bash
# Note: RuboCop is not currently included as a dependency
# The .rubocop.yml file exists for optional style checking
# To use RuboCop, add it to the Gemfile first
```

## Architecture Overview

This Ruby gem provides utilities for transforming Hash objects and generating custom JSON output. The architecture follows functional programming principles with heavy use of blocks and lambdas.

### Core Components

#### HashUtil (`lib/chatform/utils/hash_util.rb`)
Provides deep transformation of nested Hash and Array structures:
- **`convert(object, keys=[], parent: nil, key_func: nil, value_func: nil, object_func: nil)`**: Core recursive method
  - `key_func`: Lambda to transform hash keys
  - `value_func`: Lambda to transform leaf values
  - `object_func`: Lambda to filter/transform objects (return false to skip)
- **Convenience methods**: `convert_key`, `convert_value`, `convert_object` using block syntax
- **Key behavior**: Maintains parent reference and key path during traversal

#### HashUtil2 (`lib/chatform/utils/hash_util2.rb`)
Enhanced Hash transformation utility with handler chain pattern:
- **Purpose**: Transform Hash and Array structures with flexible handler chains
- **`initialize(skip_nil: false)`**: Create new transformer
- **Handler chain pattern**: Similar to JsonUtil2 but for data transformation
- **Configuration options**:
  - `skip_nil`: Whether to remove nil values from output (default: false)
- **Factory methods**: `.new_transformer`
- **Handler types**:
  - `add_handler`: Generic handler for any transformation
  - `handle_type`: Process specific object types
  - `add_value_handler`: Transform leaf values only
  - `for_key`: Match specific key patterns
  - `at_path`: Match specific object paths (e.g., "user.email")
  - `filter`: Skip elements based on conditions
- **Main method**: `transform(obj, keys=[], parent=nil)` - returns transformed object

#### JsonUtil (`lib/chatform/utils/json_util.rb`)
Original JSON generator with callback-based customization:
- **Purpose**: Generate JSON with JavaScript code literals (for `onLoad`, `onClick` etc.)
- **`initialize(opts: PRETTY_STATE_PROTOTYPE, value_func: nil, object_func: nil)`**
- **Special handling**: Preserves JavaScript arrow functions as literals instead of strings
- **Schema filtering**: Can skip objects based on `schema_enabled` property

#### JsonUtil2 (`lib/chatform/utils/json_util2.rb`)
Enhanced JSON generator with handler chain pattern:
- **Handler system**: Chain multiple handlers for complex transformations
- **Configuration options**:
  - `skip_nil`: Whether to include nil values (default: true)
  - `sort_keys`: Whether to sort hash keys alphabetically (default: false)
- **Factory methods**: `.pretty`, `.compact`, `.with_options`
- **Handler types**:
  - `add_handler`: Generic handler for any transformation
  - `handle_type`: Process specific object types
  - `add_value_handler`: Transform leaf values only
  - `for_key`: Match specific key patterns
  - `at_path`: Match specific object paths (e.g., "user.email")
  - `filter`: Skip elements based on conditions
- **Performance**: Uses StringIO for efficient string building

### Design Patterns

1. **Singleton Pattern**: All utilities use class methods, no instance state needed
2. **Chain of Responsibility**: JsonUtil2 and HashUtil2's handler chain processes objects sequentially
3. **Visitor Pattern**: Recursive traversal with customizable behavior at each node
4. **Functional Composition**: Lambdas and blocks allow flexible transformation pipelines

### Important Implementation Details

- **Frozen String Handling**: Uses `String.new` or string concatenation to avoid frozen string errors
- **Empty Array Formatting**: Special logic to match Ruby's JSON.pretty_generate output
- **Nil Handling**: Configurable behavior for nil values in JsonUtil2 and HashUtil2
- **Path Tracking**: Maintains array of keys during traversal for path-based handlers
- **Shared Error Classes**: InvalidHandlerError and InvalidPatternError defined at module level

### Testing Strategy

- **Comprehensive specs** for each utility class
- **Edge cases**: Empty collections, nil values, special characters
- **Handler composition**: Tests for complex handler chains
- **Format compatibility**: Ensures output matches standard JSON formatting where expected

## CI/CD

GitHub Actions workflow (`.github/workflows/main.yml`):
- Runs on push to master and all pull requests
- Tests against Ruby 3.0.3
- Executes default rake task (runs all specs)