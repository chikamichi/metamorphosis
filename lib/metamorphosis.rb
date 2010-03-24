$:.unshift File.dirname(__FILE__) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'pathname'
require 'configliere'

unless ENV['RAILS_ENV']
  require 'active_support/core_ext/module/attribute_accessors'
  require 'active_support/core_ext/class/attribute_accessors'
end

require 'ext/ext'
require 'metamorphosis/helpers'
require 'metamorphosis/core'

