# This module, the main one, is responsible for all hooks setup and extension mechanisms.
# Therefore, if you have a module or a class which would benefit from Metamorphosis
# features, just extend {Metamorphosis}:
#
#     MyProject.extend Metamorphosis
#
# Obviously this may look more like this in real-code:
#
#     module MyProject
#       extend Metamorphosis
#     end
#
# By extending {Metamorphosis}, `MyModule` is able to call {Metamorphosis#activate activate}
# and a bunch of `attr_reader` as class methods:
#
# * `receiver` (would return `MyProject` constant, ie. `self`)
# * `base_path` (Pathname path of the directory of the file where `MyProject` extended
#   {Metamorphosis})
# * `spells_path` (Pathname path of the spells root directory)
# * `redefinable` (list of all `MyProject`'s modules and classes spells may be defined against,
#   ie. the public API from Metamorphosis standing point)
# * `spells` (list of all activated spells for `MyProject`).
#
# Be aware of the fact that, since {Metamorphosis} is extended, the receiver does not gain
# {Metamorphosis} class methods, which are part of the private API somehow. They are
# documented nontheless so as to give you some more hints about {Metamorphosis} internals.
module Metamorphosis
  extend self

  class MetamorphosisError < StandardError; end

  # the module or class extending Metamorphosis
  mattr_reader :receiver
  # path of file where the receiver is defined
  mattr_reader :base_path
  # path of the spells directory associated to the receiver
  mattr_reader :spells_path
  # a list of all modules and classes supporting redefinitions
  # idea: manage as a RubyTree (leafs would be spells const)
  mattr_reader :redefinable
  # a list of all active spells
  mattr_reader :spells

  # Activate a spell.
  #
  # Must be called by the receiver, ie. the module or class which called
  # `extend Metamorphosis`.
  #
  # @param [String] spell_name the spell name
  # @option *syms [Boolean] :retroactive (false) if the spell alters class instances behavior,
  #   sets wether the spell should affect already existing instances once activated
  # @return [Boolean] `true` if the plugin was successfully activated, `false` otherwise
  def activate spell_name, *syms
    return Metamorphosis.activate!(spell_name, self, syms)
  end

  # ---------------------------- "private" API --------------------------------

  # @raise [MetamorphosisError]
  def self.included base
    raise MetamorphosisError, "Metamorphosis must be extended, not included (for #{base})."
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
      unless e.name =~ /#{@@receiver}::Spells/
        @@redefinable[e] ||= {}
      end
    end
  end

  # The activation process really takes place here.
  #
  # Called by {Metamorphosis#activate activate} which is part of the public API.
  # This method registers hooks between the receiver and the spell,
  # taking general or specific configuration settings into account.
  #
  # @param [String]   spell_name the spell name (from {Metamorphosis#activate activate})
  # @param [Constant] receiver    the receiver (from {Metamorphosis#activate activate})
  # @option *syms [Boolean] :retroactive (false) retroaction flag (from {Metamorphosis#activate activate})
  # @raise [LoadError] if the spell file does not exist under the expected location
  # @raise [StandardError] if the spell definition is invalid
  # @see activate
  # @return [Boolean] `true` if the plugin was successfully activated, `false` otherwise
  def self.activate!(spell_name, receiver, *syms)
    #begin
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
        #puts "************************"
        #puts "#{e.inspect} (#{receiver_constant_for inner_spell_module_from e.name})"
        #puts "************************"
        if receiver_constant_for inner_spell_module_from e.name
          # this module exists within the receiver, we're heading to redefs

          # let's say e is Receiver::Spells::ASpell::AModule::Nested::Again,
          e = e.name.split("::")[3..-1]
          # now e is AModule::Nested::Again

          # some special cases related to "Convention over Configuration"
          case e.last
          when "InstanceMethods"
            # this module handles redefs for instance methods of e[-2]
            #puts "case: InstanceMethods"
            #puts e.inspect
            #puts @@redefinable

            e_match = receiver_constant_for(e[0..-2].join("::"))
            #puts e_match

            if options[:retroactive]
              ObjectSpace.each_object(e_match) { |x| activate_on_instance x, spell_name, e }
            end

            e_match.extend RedefInit

            unless @@redefinable[e_match][spell] and @@redefinable[e_match][spell].include? :instance_methods
              (@@redefinable[e_match][spell] ||= []) << :instance_methods
            end
            e.pop

            #puts
          when "ClassMethods"
            #puts "case: ClassMethods"
            #puts e.inspect
            #pp @@redefinable

            e_match = receiver_constant_for(e[0..-2].join("::"))
            e.pop
            unless @@redefinable[e_match][spell] and @@redefinable[e_match][spell].include? :class_methods
              (@@redefinable[e_match][spell] ||= []) << :class_methods
            end

            # pending
            #puts
          else
            #puts "case: No smart-convention provided"
            #puts e.inspect
            #puts @@redefinable
            # pending

            e_match = receiver_constant_for(e[0..-1].join("::"))
            #puts e_match.inspect
            unless @@redefinable[e_match][spell] and @@redefinable[e_match][spell].include? :fresh
              (@@redefinable[e_match][spell] ||= []) << :fresh
            end

            #puts
          end

          #puts @@redefinable
          #puts
          #puts
        else
          # this module does not exist within the receiver
          #puts "^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^ Connard"
        end
      end

      @@spells << spell_name

      # TODO: unpack as an alternative to the default hook processing
      #spell.unpack if spell.respond_to?(:unpack)

      return true
    #rescue Exception => msg
      #puts msg
      #return false
    #end
  end

  # Retrieve the constant under the receiver namespace for a given name.
  # Handles nested namespaces. This method does not perform any smart
  # look-up, hence name must be a *complete* [nested] namespace[s] path under
  # the receiver's domain.
  #
  # Given the following structure:
  #
  #     module Base
  #       module Foo
  #         module Bar
  #           Class ChunkyBacon
  #             # ...
  #           end
  #         end
  #       end
  #     end
  #
  # and calls performed inside +Base+:
  #
  # @example Valid use-cases
  #
  #     receiver_constant_for("Foo") # => Base::Foo
  #     receiver_constant_for("Foo::Bar") # => Base::Foo::Bar
  #     receiver_constant_for("Base::Foo::Bar::ChunkyBacon") # => Base::Foo::Bar::ChunkyBacon
  #
  # @example Invalid use-cases
  #
  #     receiver_constant_for("Bar")
  #     receiver_constant_for("Bar::ChunkyBacon")
  #
  # @param [String, Array] name a string or an array representing a valid constant path
  # @option *syms [Boolean] :full_path (false) by default, the method gets rid of
  #   conventional namespaces (`InstanceMethods` and `ClassMethods`). Setting this
  #   option to `true` disable this behavior.
  # @return [Const, nil] a valid path constant under the receiver or `nil`
  #
  def self.receiver_constant_for name, *syms
    options = syms.extract_options!
    name = name.join("::") if name.is_a? Array

    begin
      name.gsub!(/::(InstanceMethods|ClassMethods)$/, "") unless options[:full_path]
      @@receiver.constant name
    rescue Exception
      return nil
    end
  end

  # Extracts a sub-const string matching a spell module from a valid receiver constant.
  #
  # @param [Const] name a valid receiver constant
  # @return [String] the sub-string corresponding to the inner spell module
  #
  def self.inner_spell_module_from name
    begin
      receiver_constant_for name # check validity
      return name.split("::")[3..-1].join("::")
    rescue Exception => msg
      raise ArgumentError, "Invalid receiver constant (#{msg})"
    end
  end

  # Activate a plugin for a specific instance object.
  #
  # An instance method accessor may be provided so the receiver can play too.
  #
  # @param [Object] instance the instance the spell will be activated for
  # @param [String] spell_name the spell name (eg. `"MyPlugin"`)
  # @param [Array(String)] spell_module the relative path of the spell module from spell root (eg. `["Foo", "Bar"]`)
  #
  def self.activate_on_instance instance, spell_name, spell_module
    instance.extend receiver_constant_for("Spells").constant(spell_name).constant(spell_module.join("::"))
  end

  # This module is responsible for extending forthcoming class instances with
  # the new behavior defined by relevant spell(s). It's the responsability
  # of the spells to call +super+ so as to fallback on original
  # behavior: this module only has the auto-hooks up and runing.
  #
  # In order to have instances existing prior to the plugin activation, one
  # should pass the +:retroactive+ option to {Metamorphosis#activate}.
  #
  module RedefInit
    # Redefine initialize/new so as to call extend [spells] on new
    # instances. This allows for per-instance behavior redefinitions.
    def new *args, &block
      o = super

      # notes: self is a const like Receiver::Some::Module,
      # spell_module is a const like Receiver::Spells::ASpell

      # FIXME: le bug: comme Loudness a été enregistré comme spell pour Project::Foo::Speaker,
      # la ligne 42 de test.rb arrive ici, et 299 essaye d'étendre un module InstanceMethods
      # qui n'existe pas pour Loudness. Il faut donc différencier les spells liés aux
      # InstanceMethods de ceux liés aux ClassMethods des autres dans @@redefinable.
      # C'est peut-être le moment de passer RubyTree? ou équivalent plus souple? OpenStruct?

      # FIXME: hashes don't keep insert order in Ruby 1.8 so it's not a good structure
      # to hold the spells references. Better use a tree with chained spell, spells as
      # tree leaves, and hierarchy for free.
      Metamorphosis.redefinable[self].each do |spell, modes|
        if modes.include? :instance_methods
          o.extend(spell.constant(self.name.split("::")[1..-1].join("::")).constant("InstanceMethods"))
        end
      end unless Metamorphosis.redefinable[self].empty?

      o
    end

    # TODO: handle case when object instanciation is not made using
    # initialize/#new, but a custom instance method
  end
end

