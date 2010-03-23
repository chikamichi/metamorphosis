$:.unshift File.dirname(__FILE__) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

module Metamorphosis
  # http://www.ruby-forum.com/topic/199937
  $PLUGINS_PATH = File.expand_path("../../plugins", __FILE__)

  $ROOT = File.expand_path("../..", __FILE__)
  puts $ROOT
end

require 'ext/ext'
require 'metamorphosis/core'

