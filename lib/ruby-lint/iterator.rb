module RubyLint
  ##
  # The Iterator class provides the means to iterate over an AST generated by
  # {RubyLint::Parser} using callback methods for the various node types
  # generated by this parser.
  #
  # For each node type two events are called: one before and one after
  # processing the node and all of its children. The names of these events are
  # the following:
  #
  # * `on_X`
  # * `after_X`
  #
  # Here "X" is the name of the event. For example, when iterator an integer
  # this would result in the event names `on_integer` and `after_integer`.
  #
  # These event names are used to call the corresponding callback methods if
  # they exist. Each callback method takes a single argument: the node (an
  # instance of {RubyLint::AST::Node}) that belongs to the event.
  #
  # Creating iterator classes is done by extending this particular class and
  # adding the needed methods to it:
  #
  #     class MyIterator < RubyLint::Iterator
  #       def on_int(node)
  #         puts node.children[0]
  #       end
  #
  #       def after_int(node)
  #         puts '---'
  #       end
  #     end
  #
  # When used this particular iterator class would display the values of all
  # integers it processes. After processing an integer it will display three
  # dashes.
  #
  # ## Skipping Child Nodes
  #
  # The `on_*` callbacks can tell the Iterator class to not process any
  # following child nodes by calling `skip_child_nodes!`:
  #
  #     def on_const(node)
  #       # ...
  #
  #       skip_child_nodes!(node)
  #     end
  #
  # Internally this uses `throw` and makes sure to only skip the child nodes of
  # the specified node (`throw` calls bubble up regardless of `catch` calls,
  # unlike when using `begin/rescue`).
  #
  class Iterator
    ##
    # @param [Hash] options Hash containing custom options to set for the
    #  iterator.
    #
    def initialize(options = {})
      options.each do |key, value|
        instance_variable_set("@#{key}", value)
      end

      after_initialize if respond_to?(:after_initialize)
    end

    ##
    # Recursively processes the specified list of nodes.
    #
    # @param [RubyLint::Node] node A node and optionally a set of sub nodes to
    #  iterate over.
    #
    def iterate(node)
      return unless node.is_a?(AST::Node)

      before, after = callback_names(node)
      skip_node     = catch :skip_child_nodes do
        execute_callback(before, node)
      end

      if skip_node != node
        node.children.each do |child|
          iterate(child) if child.is_a?(AST::Node)
        end
      end

      execute_callback(after, node)
    end

    protected

    ##
    # Instructs {#iterate} to not process any child nodes.
    #
    # @param [RubyLint::AST::Node] node
    #
    def skip_child_nodes!(node)
      throw :skip_child_nodes, node
    end

    ##
    # Executes the specified callback method if it exists.
    #
    # @param [String|Symbol] name The name of the callback method to execute.
    # @param [Array] args Arguments to pass to the callback method.
    #
    def execute_callback(name, *args)
      send(name, *args) if respond_to?(name)
    end

    ##
    # Returns an array containin the callback names for the specified node.
    #
    # @param [RubyLint::Node] node
    # @return [Array]
    #
    def callback_names(node)
      return ["on_#{node.type}", "after_#{node.type}"]
    end
  end # Iterator
end # RubyLint
