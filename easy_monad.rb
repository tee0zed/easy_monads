require_relative 'configuration'

require_relative 'modules/params_sanitizer'
require_relative 'modules/i18n'
require_relative 'modules/logging'

require_relative 'operation'
require_relative 'errors'

module EasyMonad
  def self.str_to_const(str)
    eval(str.split('_').map(&:capitalize).unshift('Modules::').join)
  end

  Configuration.rails_environment = !!defined?(Rails)
  Configuration.set_defaults unless Configuration.configured

  Configuration.include_modules.each do |mod|
    raise ArgumentError, 'Included Module must be a Symbol!' unless mod.is_a?(Symbol)

    Operation.include str_to_const(mod.to_s)
  end
end
