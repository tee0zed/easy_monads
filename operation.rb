# frozen_string_literal: true

module EasyMonad
  class Operation
    attr_reader :params
    attr_accessor :result, :errors

    def initialize(params, errors = Errors.new)
      @params = params
      @errors = errors
    end

    class << self
      def call(*, **)
        operation = new(*, **)

        operation.within_early_exit_block do
          operation.call

          operation
        end
      end

      alias [] call
    end

    def result!
      return result if success?

      raise ProcessError, self
    end

    def failure?
      errors.any?
    end

    def success?
      errors.empty?
    end

    def within_early_exit_block(&)
      catch(:critical, &)
    end

    def call
      raise NotImplementedError, "You must implement #call by yourself!"
    end

    protected

    def join(other)
      other.errors.each do |error, description|
        error(error, description)
      end

      other
    end

    def strict_join!(other)
      other.errors.each do |error, description|
        critical_error!(error, description)
      end

      other
    end

    private

    def error(error, description = nil)
      errors.add(error, description || 'Something went wrong')
      log_error(self)
    end

    def critical_error!(error, description = nil)
      errors.add(error, description || 'Something went wrong')
      log_critical_error(self)
      throw(:critical, self)
    end

    # stubs for Logging and ParamsSanitizer mudules
    def log_error(_) = nil
    def log_critical_error(_) = nil
    def params_for_logging(params) = params
  end

  class ProcessError < StandardError
    attr_reader :operation, :message

    def initialize(operation)
      super
      @operation = operation
      @message = "#{operation.class} Process Error"
    end
  end
end
