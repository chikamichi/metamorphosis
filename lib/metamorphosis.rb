$:.unshift File.dirname(__FILE__) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

require 'yaml'
require 'pathname'
require 'active_support/core_ext/module/attribute_accessors' unless ENV['RAILS_ENV']

require 'ext/ext'
require 'metamorphosis/helpers'
require 'metamorphosis/core'

