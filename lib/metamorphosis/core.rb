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
  # @raise [LoadError] if the spell file does not exist under the expected location
  # @raise [StandardError] if the spell definition is invalid
  # @see activate
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

