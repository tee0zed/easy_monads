# frozen_string_literal: true

module EasyMonad
  module Modules
    module ParamsSanitizer
      def params_for_logging(params)
        regex = /(#{filter_parameters.join('|')})":"([^"]*)"/
        hashed_params(params).inspect.gsub(regex, '\1":"[FILTERED]"')
      end

      private

      def hashed_params(params)
        if Configuration.rails_environment
          params.is_a? ActionController::Parameters ? params.to_unsafe_h : params.to_h
        else
          params.to_h
        end
      end

      def filter_parameters
        if Configuration.rails_environment
          Rails.configuration.filter_parameters += Configuration.filter_parameters
        else
          Configuration.filter_parameters
        end
      end
    end
  end
end
