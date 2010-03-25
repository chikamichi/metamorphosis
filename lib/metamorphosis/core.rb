module Metamorphosis
  extend self

  # the module or class extending Metamorphosis
  mattr_accessor :receiver
  # path of file where the receiver is defined
  mattr_accessor :base_path
  # path of the spells directory associated to the receiver
  mattr_accessor :plugins_path
  # a list of all modules and classes supporting redefinitions
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
  def activate plugin_name, *syms
    Metamorphosis.activate!(plugin_name, self, syms)
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

    # store each module/class const under the receiver, discarding Spells btw
    # TODO: take options :only and :except in account
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
  def self.activate!(plugin_name, receiver, *syms)
    options = syms.flatten!.extract_options!

    # TODO: handle camelcased or underscored or capitalized plugin name
    plugin_name = plugin_name.capitalize

    # TODO: read config file (generic or specific)

    # first, load the spell
    begin
      plugin_path = self.plugins_path.to_s + "/" + plugin_name.downcase
      require plugin_path
    rescue LoadError => e
      puts e
      abort "You tried to load a plugin which does not exist (#{plugin_name})."
    end
    
    # then, fetch the spell const
    begin
      plugin = self.receiver.constant("Spells").constant(plugin_name)
    rescue => e
      puts e
      abort "Invalid definition for plugin \"#{plugin_name}\". Please check #{plugin_path + ".rb"}"
    end

    # process what's inside the spell definition
    plugin.fetch_nested(recursive: true, only: :modules) do |e|
      # let's say e is Receiver::Spells::ASpell::AModule::Nested::Again,
      e = e.name.split("::")[3..-1].join("::")
      e = self.receiver.constant e
      # now e is referencing Receiver::AModule::Nested::Again

      self.redefinable[e] << self.receiver.constant("Spells").constant(plugin_name) if self.redefinable.has_key? e
      
      if options[:retroactive]
        ObjectSpace.each_object(e) { |x| p self.activate_on_instance x }
      end

      e.extend self::RedefInit
    end

    self.plugins << plugin_name

    # TODO: unpack as an alternative to the default hook processing
    #plugin.unpack if plugin.respond_to?(:unpack)
  end

  def self.activate_on_instance instance
    const = self.receiver.constant instance.class.name.split("::")[1..-1].join("::")
    self.redefinable[const].each do |plugin_module|
      instance.extend(plugin_module.constant(const.name.split("::")[1..-1].join("::")))
    end unless self.redefinable[instance.class].empty?
  end

  # This module is responsible for extending class instances with
  # new behavior defined by some plugin(s). It's the responsability
  # of the plugins to call super so as to fallback on the original
  # behavior: this module only has the auto-hooks up and runing.
  module RedefInit
    # Redefine initialize/new so as to call extend [Plugins] on new
    # instances. This allows for per-instance behavior redefinitions.
    def new *args, &block
      o = super

      # notes: self is a const like Receiver::Some::Module,
      # plugin_module is a const like Receiver::Spells::ASpell
      Metamorphosis.redefinable[self].reverse.each do |plugin_module|
        o.extend(plugin_module.constant(self.name.split("::")[1..-1].join("::"))) 
      end unless Metamorphosis.redefinable[self].empty?

      o
    end

    # TODO: handle case when object instanciation is not made using
    # initialize but a custom instance method
  end
end

