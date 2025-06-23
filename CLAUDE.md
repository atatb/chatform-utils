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
# Run all tests
rake spec
# or
bundle exec rspec

# Run specific test file
bundle exec rspec spec/chatform/hash_util_spec.rb
bundle exec rspec spec/chatform/json_util_spec.rb
bundle exec rspec spec/chatform/json_util2_spec.rb

# Run a specific test by line number
bundle exec rspec spec/chatform/json_util2_spec.rb:123
```

### Building and Installing
```bash
# Build the gem
bundle exec rake build

# Install to local system
bundle exec rake install

# Release new version (updates version, creates git tag, pushes to rubygems)
bundle exec rake release
```

## Architecture Overview

This gem provides utilities for manipulating Hash objects and JSON data in Ruby. The codebase is organized into two main utility classes:

### HashUtil (`lib/chatform/utils/hash_util.rb`)
- Provides recursive conversion methods for Hash and Array objects
- Key features:
  - `convert`: Main method that recursively transforms objects with custom key/value/object functions
  - `convert_key`, `convert_value`, `convert_object`: Convenience methods using blocks
- Supports deep transformation of nested data structures

### JsonUtil (`lib/chatform/utils/json_util.rb`) and JsonUtil2 (`lib/chatform/utils/json_util2.rb`)
- Custom JSON generation with fine-grained control over formatting and transformation
- JsonUtil: 
  - Accepts `value_func` and `object_func` callbacks for custom serialization
  - Uses JSON state objects for formatting control
- JsonUtil2:
  - Improved version with handler chain pattern
  - Presets for `pretty` and `compact` formats
  - More flexible handler system for custom transformations

### Key Patterns
1. All utilities use class methods (singleton pattern)
2. Heavy use of functional programming with lambdas/procs for transformations
3. Recursive processing of nested data structures
4. JsonUtil classes implement custom JSON generation to avoid standard library limitations

## Testing Approach
- RSpec is used for testing
- Tests are in `spec/chatform/` mirroring the lib structure
- Test files use descriptive contexts and focus on transformation behavior