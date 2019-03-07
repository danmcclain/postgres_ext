module ActiveRecord
  module QueryMethods
    [:with].each do |name|
      class_eval <<-CODE, __FILE__, __LINE__ + 1
       def #{name}_values                   # def select_values
         @values[:#{name}] || []            #   @values[:select] || []
       end                                  # end
                                            #
       def #{name}_values=(values)          # def select_values=(values)
         raise ImmutableRelation if @loaded #   raise ImmutableRelation if @loaded
         @values[:#{name}] = values         #   @values[:select] = values
       end                                  # end
      CODE
    end

    [:rank, :recursive].each do |name|
      class_eval <<-CODE, __FILE__, __LINE__ + 1
        def #{name}_value=(value)            # def readonly_value=(value)
          raise ImmutableRelation if @loaded #   raise ImmutableRelation if @loaded
          @values[:#{name}] = value          #   @values[:readonly] = value
        end                                  # end

        def #{name}_value                    # def readonly_value
          @values[:#{name}]                  #   @values[:readonly]
        end                                  # end
      CODE
    end

    def with(opts = :chain, *rest)
      if opts == :chain
        WithChain.new(spawn)
      elsif opts.blank?
        self
      else
        spawn.with!(opts, *rest)
      end
    end

    def with!(opts = :chain, *rest) # :nodoc:
      if opts == :chain
        WithChain.new(self)
      else
        self.with_values += [opts] + rest
        self
      end
    end

    def ranked(options = :order)
      spawn.ranked! options
    end

    def ranked!(value)
      self.rank_value = value
      self
    end

    def build_with(arel)
      with_statements = with_values.flat_map do |with_value|
        case with_value
        when String
          with_value
        when Hash
          with_value.map  do |name, expression|
            case expression
            when String
              select = Arel::Nodes::SqlLiteral.new "(#{expression})"
            when ActiveRecord::Relation, Arel::SelectManager
              select = Arel::Nodes::SqlLiteral.new "(#{expression.to_sql})"
            end
            Arel::Nodes::As.new Arel::Nodes::SqlLiteral.new("\"#{name.to_s}\""), select
          end
        when Arel::Nodes::As
          with_value
        end
      end
      unless with_statements.empty?
        if recursive_value
          arel.with :recursive, with_statements
        else
          arel.with with_statements
        end
      end
    end

    def build_rank(arel, rank_window_options)
      unless arel.projections.count == 1 && Arel::Nodes::Count === arel.projections.first
        rank_window = case rank_window_options
                      when :order
                        arel.orders
                      when Symbol
                        table[rank_window_options].asc
                      when Hash
                        rank_window_options.map { |field, dir| table[field].send(dir) }
                      else
                        Arel::Nodes::SqlLiteral.new "(#{rank_window_options})"
                      end

        unless rank_window.blank?
          rank_node = Arel::Nodes::SqlLiteral.new 'rank()'
          window = Arel::Nodes::Window.new
          if String === rank_window
            window = window.frame rank_window
          else
            window = window.order(rank_window)
          end
          over_node = Arel::Nodes::Over.new rank_node, window

          arel.project(over_node)
        end
      end
    end
  end
end

module RelationPrepend
  def build_arel(_alias)
    arel = super

    build_with(arel)

    build_rank(arel, rank_value) if rank_value

    arel
  end
end

ActiveRecord::Relation.prepend(RelationPrepend)
