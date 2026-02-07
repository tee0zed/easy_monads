# EasyMonad

Monad-like wrapper with early exit and fancy features for Ruby.

## WHY

### The Problem

When developing business logic in Ruby applications, the following problems often arise:

- **Scattered error handling**: try-catch blocks everywhere, no unified standard
- **Lack of early exit**: necessity to use nested conditions or multiple returns
- **Composition complexity**: difficult to combine multiple operations with proper error handling
- **Repetitive code**: logging, parameter validation, sanitization — duplicated in every service
- **Lack of standardization**: each developer solves these tasks in their own way

### The Solution

EasyMonad provides a unified pattern for:

- **Standardized error handling**: all operations return an object with a clear `success?`/`failure?` interface
- **Early exit without exceptions**: uses `catch/throw` for elegant execution interruption
- **Simple composition**: `join` and `strict_join!` methods for combining operations
- **Built-in logging**: automatic logging with performance metrics
- **Security**: automatic sanitization of sensitive parameters
- **Internationalization**: built-in support for error translations

### When to Use

✅ **Use EasyMonad when:**
- Implementing complex business logic with multiple validations
- Need transparent error handling without exceptions
- Require composition of multiple operations
- Need operation logging with metrics
- Working in a team and need a unified standard

❌ **Don't use when:**
- Simple CRUD operation without complex logic
- Need an exception specifically to interrupt execution flow
- Project is too small to add a dependency

## HOW IT WORKS

### Architecture

EasyMonad is built on three core concepts:

#### 1. Operation Pattern

```ruby
class Operation
  def call
    # Business logic
  end
  
  class << self
    def call(*args)
      operation = new(*args)
      operation.within_early_exit_block do
        operation.call
        operation
      end
    end
  end
end
```

Each operation:
- Encapsulates one business operation
- Receives parameters through constructor
- Returns itself for chaining calls
- Stores result and errors

#### 2. Early Exit via catch/throw

```ruby
def within_early_exit_block(&block)
  catch(:critical, &block)
end

def critical_error!(error, description)
  errors.add(error, description)
  throw(:critical, self)  # Immediate exit without exception
end
```

Instead of exceptions, `catch/throw` mechanism is used:
- More performant than exceptions
- Doesn't pollute stacktrace
- Explicit execution flow control

#### 3. Modular System

Modules are connected dynamically through configuration:

```ruby
Configuration.include_modules.each do |mod|
  Operation.include str_to_const(mod.to_s)
end
```

This allows:
- Selectively enable functionality
- Override module behavior
- Add custom modules

### Execution Flow

1. **Operation call**: `MyOperation.call(params)`
2. **Instance creation**: `new(params)`
3. **Wrap in early-exit block**: `catch(:critical)`
4. **Start logging** (if Logging module is enabled)
5. **Business logic execution**: `call`
6. **Error handling**:
   - `error()` — adds error, continues execution
   - `critical_error!()` — adds error, performs `throw(:critical)`
7. **Completion logging**
8. **Return operation** with result and errors

### Errors Object

Inherits from Hash for ease of use:

```ruby
class Errors < Hash
  def add(key, value)
    self[key] ||= value  # Doesn't overwrite existing error
  end
end
```

This allows:
- Store multiple errors
- Avoid duplication
- Easy presence check: `errors.any?`

### Module Integration

#### Logging Module

Overrides the class method `call`:

```ruby
def self.call(*args)
  operation = new(*args)
  operation.within_early_exit_block do
    operation.log_start(operation)
    operation.call
    operation.log_end(operation)
    operation
  end
end
```

#### ParamsSanitizer Module

Uses regex to replace sensitive data:

```ruby
def params_for_logging(params)
  regex = /(#{filter_parameters.join('|')})":"([^"]*)"/
  params.inspect.gsub(regex, '\1":"[FILTERED]"')
end
```

#### I18n Module

Forms translation key from class name:

```ruby
def desc(error)
  I18n.t("operations.#{self.class.name.underscore.gsub('/', '.')}.#{error}")
end
```

## Installation

Add to your Gemfile:

```ruby
gem 'easy_monad'
```

Then execute:

```bash
bundle install
```

Or install directly:

```bash
gem install easy_monad
```

## Requirements

- Ruby >= 3.3.1

## Usage

### Basic Usage

Create an operation class by inheriting from `EasyMonad::Operation`:

```ruby
class MyOperation < EasyMonad::Operation
  def call
    # Your business logic here
    @result = perform_some_work
    
    # Adding an error
    error(:invalid_data, 'Data is invalid') if invalid?
    
    self
  end
  
  private
  
  def perform_some_work
    # Implementation
  end
  
  def invalid?
    # Validation
  end
end
```

Calling an operation:

```ruby
operation = MyOperation.call(params: { key: 'value' })

if operation.success?
  puts "Result: #{operation.result}"
else
  puts "Errors: #{operation.errors}"
end
```

### Working with Errors

EasyMonad supports two types of errors:

#### Regular Errors

```ruby
def call
  error(:validation_error, 'Email is invalid') unless valid_email?
  # Operation continues execution
end
```

#### Critical Errors (early exit)

```ruby
def call
  critical_error!(:unauthorized, 'Authorization required') unless authorized?
  # Code below will not execute if error occurred
end
```

### Status Checking

```ruby
operation = MyOperation.call(params)

operation.success?  # => true if no errors
operation.failure?  # => true if there are errors
operation.result    # => operation result
operation.result!   # => result or raises ProcessError on errors
```

### Joining Operations

#### join - soft join

```ruby
def call
  other_operation = AnotherOperation.call(params)
  join(other_operation)  # Merges errors, continues execution
end
```

#### strict_join! - strict join

```ruby
def call
  other_operation = AnotherOperation.call(params)
  strict_join!(other_operation)  # Interrupts execution if errors present
end
```

### Errors Object

```ruby
operation.errors.add(:key, 'Error description')
operation.errors.to_a          # => ["key: Error description"]
operation.errors.to_s          # => "key: Error description"
operation.errors.only_messages # => ["Error description"]
```

## Configuration

### Basic Configuration

```ruby
EasyMonad::Configuration.configure do |config|
  config.logger = Rails.logger  # Your logger
  config.include_modules = [:params_sanitizer, :logging, :i18n]
  config.filter_parameters = %w[password secret token]
end
```

### Configuration Parameters

- `logger` - logger for output messages (default: `Logger.new(STDOUT)`)
- `include_modules` - modules to include (default: `[:params_sanitizer, :logging, :i18n]`)
- `filter_parameters` - parameters to filter in logs (default: `['password', 'password_confirmation', 'secret', 'password_salt']`)
- `rails_environment` - automatically detects Rails presence
- `configured` - configuration flag

## Modules

### Logging

Automatically logs operation start and end, as well as errors:

```ruby
# Logs automatically include:
# - Operation start time
# - Operation end time
# - Execution duration
# - Parameters (with sanitization)
# - Errors (if any)
```

### ParamsSanitizer

Filters sensitive parameters in logs:

```ruby
# Parameters from filter_parameters will be replaced with [FILTERED]
operation.call(params: { email: 'test@test.com', password: 'secret123' })
# In logs: { email: 'test@test.com', password: '[FILTERED]' }
```

### I18n

Internationalization support for error descriptions:

```ruby
def call
  error(:invalid_email, desc(:invalid_email))
end

# In localization file:
# operations:
#   my_operation:
#     invalid_email: "Email address is invalid"
```

### Disabling Modules

If you don't need certain modules:

```ruby
EasyMonad::Configuration.configure do |config|
  config.include_modules = [:logging]  # Only logging
end
```

## Usage Examples

### Example 1: Simple Validation

```ruby
class ValidateUser < EasyMonad::Operation
  def call
    error(:empty_name, 'Name cannot be empty') if params[:name].blank?
    error(:empty_email, 'Email cannot be empty') if params[:email].blank?
    
    @result = { valid: true } if success?
    self
  end
end

operation = ValidateUser.call(params: { name: '', email: 'test@test.com' })
operation.errors # => { empty_name: 'Name cannot be empty' }
```

### Example 2: Operation Chain

```ruby
class CreateUser < EasyMonad::Operation
  def call
    validation = ValidateUser.call(params)
    strict_join!(validation)
    
    user = User.create(params)
    critical_error!(:creation_failed, 'Failed to create user') unless user.persisted?
    
    @result = user
    self
  end
end
```

### Example 3: Using Alternative Syntax

```ruby
# Using [] instead of call
operation = MyOperation[params: { key: 'value' }]
```

## Exception Handling

```ruby
begin
  result = MyOperation.call(params).result!
  # Working with result
rescue EasyMonad::ProcessError => e
  puts "Operation #{e.operation.class} completed with errors"
  puts "Errors: #{e.operation.errors}"
end
```

## Rails Integration

EasyMonad automatically detects Rails environment and integrates with:

- `ActionController::Parameters` for parameter sanitization
- `Rails.configuration.filter_parameters` for parameter filtering
- `Rails.logger` (if configured)
- `I18n` for localization

## Development

### Running Tests

```bash
bundle exec rspec
```

## License

The gem is available as open source under the [MIT License](https://opensource.org/licenses/MIT).

## Author

T.Zhuk (tee0zed@gmail.com)

## Version

0.0.3
