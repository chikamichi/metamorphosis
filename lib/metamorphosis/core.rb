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

  # FIXME
  # en fait, à part activate, je dois pouvoir tout passer en private, non ?

  # FIXME
  # le transformer en attr_reader peut-être ?
  # The base module or class which called extend Pluginable
  def self.receiver
    @receiver ||= nil
  end

  # This hash holds the plugins hooks. Its structure is like this:
  # a module or class within the receiver => array of plugins performing redef on it
  def self.redefinable #:nodoc:
    @redefinable ||= {}
  end

  # path
  def self.base_path #:nodoc:
    @base_path ||= nil
  end

  def self.plugins_path #:nodoc:
    @plugins_path ||= nil
  end

  def self.plugins #:nodoc:
    @plugins ||= []
  end

  # A list of all active plugins.
  def plugins
    Metamorphosis.plugins
  end

  def self.extended base #:nodoc:
    # the receiver is the extended module or class
    # which is willing to metamorphose
    @receiver = base

    # paths of the receiver file and receiver plugins
    @base_path = base_path.to_s

    # TODO
    # read metamorphosis config file
    # config keys:
    # - :only
    # - :only_under
    # - :except
    # - :location    => location of the spell/metamorphose/plugins/whateveryoucallit files
    #                   (defaults to "circe", the greek godess of transformation)
    #                    This string is used, capitalized, as the module name to be used
    #                    when defining s/m/p/wyoucallit
    # - ?

    @plugins_path = @base_path + "circe"

    # TODO
    # peut-être à terme à bouger dans une méthode self.init
    # de façon à pouvoir découpler le extend de l'initialization,
    # ce qui permettrait entre temps de configurer un peu son
    # Pluginable (options :only, :except, etc.)
    # Ou sinon, garder ça ici et mettre la conf dans un fichier tiers,
    # à lire juste avant le fetch_nested de façon à pouvoir affiner la
    # clause unless
    base.fetch_nested(recursive: true) do |e|
      redefinable[e] ||= [] unless e.name =~ /#{@receiver}::Plugin/
    end
  end

  # Activate a plugin.
  #
  # Must be called by the receiver, ie. the module or class which called
  # <code>extend Pluginable</code>.
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
  def activate plugin_name
    # be careful about self here, need to explicit Pluginable

    # TODO: gérer en arguments les chaines et les symboles,
    # camelcased on underscored (faire un helper private)

    plugin_name = plugin_name.capitalize

    begin
      require Metamorphosis.plugins_path.to_s + "/" + plugin_name.downcase
    rescue LoadError => e
      puts e
      abort "You tried to load a plugin which does not exist (#{plugin_name})."
    end
    
    begin
      plugin = Metamorphosis.receiver.const_get("Plugin").const_get(plugin_name)
    rescue => e
      puts e
      abort "Invalid definition for plugin \"#{plugin_name}\". Please check #{Metamorphosis.base_path + "/" + plugin_name.downcase + ".rb"}"
    end

    Metamorphosis.plugins << plugin_name
    plugin.fetch_nested(recursive: true, only: :modules) do |e|
      e = e.name.split("::").last
      e = Metamorphosis.receiver.const_get e

      #puts
      e.extend ::Metamorphosis::PluginInit
      #puts
      Metamorphosis.redefinable[e] << Metamorphosis.receiver.const_get("Plugin").const_get(plugin_name) if Metamorphosis.redefinable.has_key? e
    end
    plugin.unpack if plugin.respond_to?(:unpack)
    #puts Metamorphosis.redefinable.inspect
  end

  # TODO
  # idées :
  # - utiliser un hack type unextend (cf ext/ext.rb)
  # - http://ruby-doc.org/core/classes/Module.html#M001654 pour #undef_method, #define_method
  # - gérer les plugins avec BlankSlate (http://github.com/masover/blankslate) : je pense que c'est le mieux,
  #   mais ça demande un peu de boulot.
  #def shutdown plugin_name
    #p self.class_eval("class << self; self; end").ancestors.inspect
    #plugins_list = self.plugins
    #self.unextend
    #p self.class_eval("class << self; self; end").ancestors.inspect
  #end

  # TODO
  # def bypass
  # end

  # This module is responsible for extending class instances with
  # new behavior defined by some plugin(s). It's the responsability
  # of the plugins to call super or not so as to fallback on the
  # original behavior: this module only has the hooks up and running.
  module PluginInit
    #def self.extended base
      #puts "PluginInit extended by #{base}"
      #puts base.class_eval("class << self; self; end").ancestors.inspect
    #end

    # Redefine initialize/new so as to call extend on new instances.
    def new *args, &block
      #puts "--------- Initializing through PluginInit for #{self}"
      o = super
      #puts "super: #{o}"
      #puts "self: #{self}"
      #puts Metamorphosis.redefinable
      #puts Metamorphosis.redefinable[self].first.class
      #puts "---------"
      #puts o.instance_eval("class << self; self; end").ancestors.inspect
      Metamorphosis.redefinable[self].reverse.each do |plugin_module|
        o.extend(plugin_module.const_get(self.name.split("::").last)) 
      end unless Metamorphosis.redefinable[self].empty?
      #puts o.instance_eval("class << self; self; end").ancestors.inspect
      o
    end
  end
end

