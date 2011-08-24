class Object
  # Nice little hack allowing to unextend modules.
  #
  # @see http://gist.github.com/149878
  # @see http://www.ruby-forum.com/topic/150696
  #
  def unextend
    self.replace dup
  end

  # Look out for any class and/or module defined within the receiver.
  # The receiver must be a class or a module.
  #
  # call-seq:
  #   MyModule.fetch_nested                        => returns a flat array of every first-level nested classes and modules
  #   MyModule.fetch_nested(:only => :classes)     => returns a flat array of every first-level nested classes
  #   MyModule.fetch_nested(:only => :modules)     => returns a flat array of every first-level nested modules
  #   MyModule.fetch_nested(:recursive => true)    => performs a recursive search through descendants, returns one flat array
  #   MyModule.fetch_nested([options]) { |e| ... } => yield elements
  #
  # The matching elements are returned or yielded as Class or Module, so
  # one can use them directly to instanciate, mixin...
  #
  # Beware that when using the block form, the same element may be yielded
  # several times, depending on inclusions and requirements redundancy.
  # The flat array contains uniq entries.
  # # TODO: monitor yielded elements and yield uniq
  #
  def fetch_nested(*args)
    options = {:recursive => false, :only => false}.merge! Hash[*args]
    #unless (options.reject { |k, v| [:recursive, :only].include? k }).empty?
      #raise ArgumentError, "Unexpected argument(s) (should be :recursive and/or :only)"
    #end

    consts = []
    if self.is_a? Module or self.is_a? Class
      consts = case options[:only]
        when :classes
          self.constants.map { |c| self.const_get c }.grep(Class)
        when :modules
          tmp = self.constants.map { |c| self.const_get c }
          tmp.grep(Module) - tmp.grep(Class)
        when false
          self.constants.map { |c| self.const_get c }.grep(Module)
      end

      if consts.empty?
        return nil
      else
        if options[:recursive]
          consts.each do |c|
            if block_given?
              c.fetch_nested(recursive: true, only: options[:only]) { |nested| yield nested }
            else
              nested = c.fetch_nested(recursive: true, only: options[:only])
              (consts << nested).flatten! unless nested.nil?
            end
          end
        end
        if block_given?
          consts.uniq.each { |c| yield c }
        else
          return consts.uniq
        end
      end
    else
      # neither a class or a module
      return nil
    end
  end
end
