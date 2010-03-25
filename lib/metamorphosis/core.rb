module Metamorphosis
  extend self

  # the module or class extending Metamorphosis
  mattr_reader :receiver
  # path of file where the receiver is defined
  mattr_reader :base_path
  # path of the spells directory associated to the receiver
  mattr_reader :spells_path
  # a list of all modules and classes supporting redefinitions
  mattr_reader :redefinable
  # a list of all active spells
  mattr_reader :spells

  # Activate a spell.
  #
  # Must be called by the receiver, ie. the module or class which called
  # <code>extend Metamorphosis</code>.
  #
  # @param [String] spell_name the spell name
  # @option *syms [Boolean] :retroactive (false) wether the plugin should affect existing instances
  def activate spell_name, *syms
    Metamorphosis.activate!(spell_name, self, syms)
  end

  def self.extended base
    @@receiver    = base
    @@base_path   = receiver_base_path
    @@spells_path = Pathname.new(@@base_path.to_s + "/" + "spells")
    @@spells      = []
    @@redefinable = {}

    # TODO
    # at this point, read metamorphosis config file (.metamorphosis.yml)
    # which may define some config keys:
    # - :only        => array of Const; only those consts will be added to :redefinable
    # - :only_under  => look out for nested module/class only under one or several
    #                   specified module(s)/class(es) (makes your public API really explicit)
    # - :except      => array of Const to bypass when building :redefinable
    # - :namespace   => name of the spell/metamorphose/spells/whateveryoucallit namespace
    #                   (defaults to "spells", but I guess many will go for "spells")
    #                   This string is used, capitalized, as the module name to be used
    #                   when defining s/m/p/wyoucallit
    # And add the possibility to have several config files (one by subfolder under spells/)

    # store each module/class const under the receiver, discarding Spells btw
    # TODO: take options :only and :except in account
    @@receiver.fetch_nested(recursive: true) do |e|
      @@redefinable[e] ||= [] unless e.name =~ /#{@@receiver}::Spells/
    end
  end

  # The activation process really takes place here.
  #
  # Called by <tt>activate</tt> which is part of the public API.
  # This method registers hooks between the receiver and the spell,
  # taking general or specific configuration settings into account.
  #
  # @param [String]   spell_name the spell name
  # @param [Constant] receiver    the receiver
  # @raise [LoadError] if the spell file does not exist under the expected location
  # @raise [StandardError] if the spell definition is invalid
  # @see activate
  def self.activate!(spell_name, receiver, *syms)
    options = syms.flatten!.extract_options!

    # TODO: handle camelcased or underscored or capitalized spell name
    spell_name = spell_name.capitalize

    # TODO: read config file (generic or specific)

    # first, load the spell
    begin
      spell_path = Pathname.new(@@spells_path.to_s + "/" + spell_name.downcase)
      require spell_path.to_s
    rescue LoadError => e
      puts e
      abort "You tried to load a spell which does not exist (#{spell_name})."
    end
    
    # then, fetch the spell const
    begin
      spell = @@receiver.constant("Spells").constant(spell_name)
    rescue => e
      puts e
      abort "Invalid definition for spell \"#{spell_name}\". Please check #{spell_path.to_s + ".rb"}"
    end

    # process what's inside the spell definition
    spell.fetch_nested(recursive: true, only: :modules) do |e|
      # let's say e is Receiver::Spells::ASpell::AModule::Nested::Again,
      e = e.name.split("::")[3..-1].join("::")
      e = @@receiver.constant e
      # now e is referencing Receiver::AModule::Nested::Again

      @@redefinable[e] << @@receiver.constant("Spells").constant(spell_name) if @@redefinable.has_key? e
      
      if options[:retroactive]
        ObjectSpace.each_object(e) { |x| p activate_on_instance x }
      end

      e.extend RedefInit
    end

    @@spells << spell_name

    # TODO: unpack as an alternative to the default hook processing
    #spell.unpack if spell.respond_to?(:unpack)
  end

  def self.activate_on_instance instance
    const = @@receiver.constant instance.class.name.split("::")[1..-1].join("::")
    @@redefinable[const].each do |spell_module|
      instance.extend(spell_module.constant(const.name.split("::")[1..-1].join("::")))
    end unless @@redefinable[instance.class].empty?
  end

  # This module is responsible for extending class instances with
  # new behavior defined by some spell(s). It's the responsability
  # of the spells to call super so as to fallback on the original
  # behavior: this module only has the auto-hooks up and runing.
  module RedefInit
    # Redefine initialize/new so as to call extend [spells] on new
    # instances. This allows for per-instance behavior redefinitions.
    def new *args, &block
      o = super

      # notes: self is a const like Receiver::Some::Module,
      # spell_module is a const like Receiver::Spells::ASpell
      Metamorphosis.redefinable[self].reverse.each do |spell_module|
        o.extend(spell_module.constant(self.name.split("::")[1..-1].join("::"))) 
      end unless Metamorphosis.redefinable[self].empty?

      o
    end

    # TODO: handle case when object instanciation is not made using
    # initialize but a custom instance method
  end
end

