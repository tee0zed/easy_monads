# frozen_string_literal: true

require_relative 'params_sanitizer'

module EasyMonad
  module Modules
    module Logging
      def self.call(*, **)
        operation = new(*, **)

        operation.within_early_exit_block do
          operation.log_start(operation)
          operation.call
          operation.log_end(operation)

          operation
        end
      end

      private

      def log_start(operation)
        memoize_start_time
        logger.info "Operation #{operation.class.name} starts params: #{operation.params_for_logging(operation.params)}"
      end

      def log_end(operation)
        logger.info "Operation #{operation.class.name} ends. Took: #{duration_from_start_in_secs} sec, params: #{operation.params_for_logging(operation.params)}"
      end

      def log_critical_error(operation)
        logger.error "Operation #{operation.class.name} ends with error. Took: #{duration_from_start_in_secs} sec, params: #{operation.params_for_logging(operation.params)}, errors: #{operation.errors.to_a}"
      end

      def log_error(operation)
        logger.error "Operation #{operation.class.name} has errors: #{operation.errors.to_a} params: #{operation.params_for_logging(operation.params)}"
      end

      def duration_from_start_in_secs
        (cpu_clock_now - start_time).floor(2)
      end

      def memoize_start_time
        @start_time = cpu_clock_now
      end

      def logger
        Configuration.logger
      end

      def start_time
        @start_time
      end

      def cpu_clock_now
        Process.clock_gettime(Process::CLOCK_MONOTONIC)
      end
    end
  end
end
