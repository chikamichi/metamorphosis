$:.unshift File.dirname(__FILE__) unless
  $:.include?(File.dirname(__FILE__)) || $:.include?(File.expand_path(File.dirname(__FILE__)))

module Metamorphosis
  # http://www.ruby-forum.com/topic/199937
  $PLUGINS_PATH = File.expand_path("../../plugins", __FILE__)
end

require 'ext/ext'
require 'metamorphosis/core'

