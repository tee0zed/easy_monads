module EasyMonad
  class Configuration
    class << self
      attr_accessor :logger,
                    :include_modules,
                    :filter_parameters,
                    :rails_environment,
                    :configured

      def set_defaults
        @logger = ::Logger.new(STDOUT)
        @include_modules = [:params_sanitizer, :logging, :i18n]
        @filter_parameters = %w[
          password
          password_confirmation
          secret
          password_salt
        ]
      end

      def configure
        yield self

        @configured = true
      end
    end
  end
end
