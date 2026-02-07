# frozen_string_literal: true

module EasyMonad
  module Modules
    module I18n
      def desc(error)
        ::I18n.t("operations.#{self.class.name.underscore.gsub('/', '.')}.#{error}")
      end
    end
  end
end
