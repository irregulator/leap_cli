module LeapCli; end

$ruby_version = RUBY_VERSION.split('.').collect{ |i| i.to_i }.extend(Comparable)

require 'leap/platform.rb'

require 'leap_cli/version.rb'
require 'leap_cli/constants.rb'
require 'leap_cli/requirements.rb'
require 'leap_cli/exceptions.rb'

require 'leap_cli/leapfile.rb'
require 'core_ext/hash'
require 'core_ext/boolean'
require 'core_ext/nil'
require 'core_ext/string'
require 'core_ext/json'

require 'leap_cli/log'
require 'leap_cli/path'
require 'leap_cli/util'
require 'leap_cli/util/secret'
require 'leap_cli/util/remote_command'
require 'leap_cli/util/x509'
require 'leap_cli/logger'

require 'leap_cli/ssh_key'
require 'leap_cli/config/object'
require 'leap_cli/config/node'
require 'leap_cli/config/tag'
require 'leap_cli/config/provider'
require 'leap_cli/config/secrets'
require 'leap_cli/config/object_list'
require 'leap_cli/config/manager'

require 'leap_cli/markdown_document_listener'

module LeapCli::Commands; end

#
# allow everyone easy access to log() command.
#
module LeapCli
  Util.send(:extend, LeapCli::Log)
  Commands.send(:extend, LeapCli::Log)
  Config::Manager.send(:include, LeapCli::Log)
  extend LeapCli::Log
end
