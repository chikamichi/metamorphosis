# Metamorphosis. Let's do some differentiation!
# 
# Metamorphosis is a generic plugins system. Using Metamorphosis,
# a module or a class is able to alter and/or extend its original
# nature.
#
#
# It means the module or class will be able to activate plugins
# which have been written on the purpose of adding new or redefining
# existing behaviors.
#
# Plugins can alter class or instance methods, within modules or classes.
# A convention in plugins definitions makes it possible to auto-discover
# which modules or classes of the receiver are concerned by the plugin
# to be activated. Those modules or classes will gain some new behavior
# if the plugin declares so, while retaining the ability to fallback on
# their original behavior via simple inheritance. Pluginable will also
# automagically hook class and instance methods in their proper location
# if a simple structure convention is followed in the plugin definition.
#
# TODO
# The hooking process can be configured (no more automagical hooking)
# using the unpack method each plugin may provide:
#   def unpack
#     # ... design pending
#   end
#
# If several plugins are activated and performs some redefinitions
# in a class or module of the receiver, one has to pay extra attention
# to chained behavior and inconsistency. It's good practice to always
# call super at some point so as to traverse the all plugins inheritance
# chain until the original definition is reached.
#
# If you want to completely overwrite the original behavior while being
# able to activate multiple plugins, a nice way to go is to write a
# SuperPlugin which redefines the method you're targeting at, without
# calling super. Activate this SuperPlugin first, then activate the other
# plugins, using super in their redefinitions so as to reach the SuperPlugin
# implementation in the end.
#
# TODO
# If you want to bold-skip a plugin once, you may first check wether
# it's activated using MyProject.plugins. If so, you may then call
# <code>MyProject.bypass :plugin_name</code>, which will perform
# <code>shutdown</code> and <code>activate</code> in sequence while
# retaining the inheritance position of the bypassed plugin.
module Metamorphosis
  extend self

  # the module or class extending Metamorphosis
  mattr_accessor :receiver
  # path of file where the receiver is defined
  mattr_accessor :base_path
  # path of the spells directory associated to the receiver
  mattr_accessor :plugins_path
  # a list of all modules or classes allowed to be altered by spells
  mattr_accessor :redefinable
  # a list of all active spells
  mattr_accessor :plugins

  # Activate a plugin.
  #
  # Must be called by the receiver, ie. the module or class which called
  # <code>extend Metamorphosis</code>.
  #
  #   module MyProject
  #     extend Pluginable
  #
  #     class Foo
  #       # ...
  #     end
  #
  #     class Server
  #       def initialize
  #         MyProject.activate :some_super_plugin_I_wrote
  #         MyProject.activate "anotherPlugin"
  #       end
  #     end
  #   end
  #
  # @param [String] plugin_name the plugin name
  def activate plugin_name
    Metamorphosis.activate!(plugin_name, self)
  end

  def self.extended base
    self.receiver = base
    self.base_path = instance_base_path.to_s
    self.plugins_path = self.base_path + "/" + "spells"
    self.plugins = []

    # TODO
    # at this point, read metamorphosis config file (.metamorphosis.yml)
    # which may define some config keys:
    # - :only        => array of Const; only those consts will be added to :redefinable
    # - :only_under  => look out for nested module/class only under one or several
    #                   specified module(s)/class(es) (makes your public API really explicit)
    # - :except      => array of Const to bypass when building :redefinable
    # - :namespace   => name of the spell/metamorphose/plugins/whateveryoucallit namespace
    #                   (defaults to "spells", but I guess many will go for "plugins")
    #                   This string is used, capitalized, as the module name to be used
    #                   when defining s/m/p/wyoucallit
    # And add the possibility to have several config files (one by subfolder under spells/)

    self.redefinable = {}
    self.receiver.fetch_nested(recursive: true) do |e|
      self.redefinable[e] ||= [] unless e.name =~ /#{self.receiver}::Spells/
    end
  end

  # The activation process really takes place here.
  #
  # Called by <tt>activate</tt> which is part of the public API.
  # This method registers hooks between the receiver and the plugin,
  # taking general or specific configuration settings into account.
  #
  # @param [String]   plugin_name the plugin name
  # @param [Constant] receiver    the receiver
  def self.activate!(plugin_name, receiver)
    # TODO: handle camelcased or underscored or capitalized plugin name
    plugin_name = plugin_name.capitalize

    # TODO: read config file (generic or specific)

    begin
      require self.plugins_path.to_s + "/" + plugin_name.downcase
    rescue LoadError => e
      puts e
      abort "You tried to load a plugin which does not exist (#{plugin_name})."
    end
    
    begin
      plugin = self.receiver.const_get("Spells").const_get(plugin_name)
    rescue => e
      puts e
      abort "Invalid definition for plugin \"#{plugin_name}\". Please check #{self.base_path + "/" + plugin_name.downcase + ".rb"}"
    end

    self.plugins << plugin_name
    plugin.fetch_nested(recursive: true, only: :modules) do |e|
      e = e.name.split("::").last
      e = self.receiver.const_get e

      e.extend self::RedefInit
      self.redefinable[e] << self.receiver.const_get("Spells").const_get(plugin_name) if self.redefinable.has_key? e
    end

    # TODO: unpack as an alternative to the default hook processing
    #plugin.unpack if plugin.respond_to?(:unpack)
  end

  # This module is responsible for extending class instances with
  # new behavior defined by some plugin(s). It's the responsability
  # of the plugins to call super so as to fallback on the original
  # behavior: this module only has the auto-hooks up and runing.
  module RedefInit
    # Redefine initialize/new so as to call extend on new instances.
    # This allows for per-instance behavior redefinitions.
    def new *args, &block
      o = super

      Metamorphosis.redefinable[self].reverse.each do |plugin_module|
        o.extend(plugin_module.const_get(self.name.split("::").last)) 
      end unless Metamorphosis.redefinable[self].empty?

      o
    end
  end
end

