module Rlint
  ##
  # {Rlint::Scope} is a class used for storing scoping related information such
  # as the methods that are available for various constants, variables that
  # have been defined, etc.
  #
  # Each instance of this class can also have a number of parent scopes. These
  # parent scopes can be used to look up data that is inherited in Ruby code
  # (e.g. constants).
  #
  # Basic example of using this class:
  #
  #     scope = Rlint::Scope.new
  #
  #     scope.lookup(:local_variable, 'name') # => nil
  #
  #     scope.add(:local_variable, 'name', 'Ruby')
  #
  #     scope.lookup(:local_variable, 'name') # => "Ruby"
  #
  class Scope
    ##
    # Array containing symbol names that should be looked up in the parent
    # scopes if they're not found in the current scope.
    #
    # @return [Array]
    #
    LOOKUP_PARENT = [
      :instance_variable,
      :class_variable,
      :global_variable,
      :method,
      :instance_method,
      :constant
    ]

    ##
    # Array containing the parent scopes, set to an empty Array by default.
    #
    # @return [Array]
    #
    attr_reader :parent

    ##
    # Hash containing all the symbols (local variables, methods, etc) for the
    # current scope instance.
    #
    # @return [Hash]
    #
    attr_reader :symbols

    ##
    # The constant to lazy import child constants from, set to `Object` by
    # default.
    #
    # @return [Mixed]
    #
    attr_reader :constant

    ##
    # Creates a new instance of the scope class and sets the default symbols.
    #
    # @param [Array|Rlint::Scope] parent The parent scope(s). Set this to an
    #  Array of {Rlint::Scope} instances to use multiple parent scopes.
    # @param [TrueClass|FalseClass] lazy When set to `true` core constants will
    #  be lazy loaded when they're not already defined.
    # @param [TrueClass|FalseClass] kernel When set to `true` the instance
    #  will try to import constants for each failed constant lookup.
    # @param [Mixed] constant See Rlint::Scope#constant.
    #
    def initialize(parent = [], lazy = false, kernel = false, constant = Object)
      unless parent.is_a?(Array)
        parent = [parent]
      end

      @parent  = parent.select { |p| p.is_a?(Rlint::Scope) }
      @symbols = {
        :local_variable    => {},
        :instance_variable => {},
        :class_variable    => {},
        :global_variable   => {},
        :constant          => {},
        :method            => {},
        :instance_method   => {}
      }

      @constant      = constant
      @lazy_load     = lazy
      @import_kernel = kernel

      if lazy and kernel
        @symbols[:constant] = ConstantImporter.import(['Kernel'])
      end
    end

    ##
    # Adds a new symbol to the scope.
    #
    # @param [#to_sym] type The type of symbol to add.
    # @param [String] name The name of the symbol.
    # @param [Mixed] value The value to store under the specified name.
    #
    def add(type, name, value = nil)
      @symbols[type.to_sym][name] = value
    end

    ##
    # Looks up a symbol in the current and parent scopes (if there are any).
    #
    # @param [#to_sym] type The type of symbol to look up.
    # @param [String] name The name of the symbol to look up.
    #
    def lookup(type, name)
      name   = name.to_s unless name.is_a?(String)
      symbol = nil
      type   = type.to_sym

      if @symbols[type] and @symbols[type][name]
        symbol = @symbols[type][name]
      # Look up the variable in the parent scope(s) (if any are set).
      elsif LOOKUP_PARENT.include?(type) and !@parent.empty?
        @parent.each do |parent|
          parent_symbol = parent.lookup(type, name)

          if parent_symbol
            symbol = parent_symbol
            break
          end
        end
      end

      # Lazy import the constant if it exists.
      if @lazy_load and type == :constant and !symbol \
      and @constant.constants.include?(name.to_sym)
        @symbols[:constant] = @symbols[:constant].merge(
          ConstantImporter.import([name], @constant)
        )

        symbol = lookup(type, name)
      end

      return symbol
    end
  end # Scope
end # Rlint
