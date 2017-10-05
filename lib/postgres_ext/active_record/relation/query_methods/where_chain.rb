module ActiveRecord
  module QueryMethods
    class WhereChain
      def overlap(opts, *rest)
        substitute_comparisons(opts, rest, Arel::Nodes::Overlap, 'overlap')
      end

      def contained_within(opts, *rest)
        substitute_comparisons(opts, rest, Arel::Nodes::ContainedWithin, 'contained_within')
      end

      def contained_within_or_equals(opts, *rest)
        substitute_comparisons(opts, rest, Arel::Nodes::ContainedWithinEquals, 'contained_within_or_equals')
      end

      def contains(opts, *rest)
        build_where_chain(opts, rest) do |rel|
          case rel
          when Arel::Nodes::In, Arel::Nodes::Equality
            column = left_column(rel) || column_from_association(rel)
            equality_for_hstore(rel) if column.type == :hstore

            if column.type == :hstore
              Arel::Nodes::ContainsHStore.new(rel.left, rel.right)
            elsif column.respond_to?(:array) && column.array
              Arel::Nodes::ContainsArray.new(rel.left, rel.right)
            else
              Arel::Nodes::ContainsINet.new(rel.left, rel.right)
            end
          else
            raise ArgumentError, "Invalid argument for .where.overlap(), got #{rel.class}"
          end
        end
      end

      def contained_in_array(opts, *rest)
        build_where_chain(opts, rest) do |rel|
          case rel
          when Arel::Nodes::In, Arel::Nodes::Equality
            column = left_column(rel) || column_from_association(rel)
            equality_for_hstore(rel) if column.type == :hstore

            if column.type == :hstore
              Arel::Nodes::ContainedInHStore.new(rel.left, rel.right)
            elsif column.respond_to?(:array) && column.array
              Arel::Nodes::ContainedInArray.new(rel.left, rel.right)
            else
              Arel::Nodes::ContainsINet.new(rel.left, rel.right)
            end
          else
            raise ArgumentError, "Invalid argument for .where.overlap(), got #{rel.class}"
          end
        end
      end

      def contains_or_equals(opts, *rest)
        substitute_comparisons(opts, rest, Arel::Nodes::ContainsEquals, 'contains_or_equals')
      end

      def any(opts, *rest)
        equality_to_function('ANY', opts, rest)
      end

      def all(opts, *rest)
        equality_to_function('ALL', opts, rest)
      end

      private

      def find_column(col, rel)
        col.name == rel.left.name.to_s || col.name == rel.left.relation.name.to_s
      end

      def column_from_association(rel)
        if assoc = assoc_from_related_table(rel)
          column = assoc.klass.columns.find { |col| find_column(col, rel) }
        end
      end

      def equality_for_hstore(rel)
        new_right_name = rel.left.name.to_s
        if rel.right.respond_to?(:val)
          return if rel.right.val.is_a?(Hash)
          rel.right = Arel::Nodes.build_quoted({new_right_name => rel.right.val},
                                               rel.left)
        else
          return if rel.right.is_a?(Hash)
          rel.right = {new_right_name => rel.right }
        end

        rel.left.name = rel.left.relation.name.to_sym
        rel.left.relation.name = @scope.klass.table_name
      end

      def assoc_from_related_table(rel)
        @scope.klass.reflect_on_association(rel.left.relation.name.to_sym) ||
          @scope.klass.reflect_on_association(rel.left.relation.name.singularize.to_sym)
      end

      def substitute_comparisons(opts, rest, arel_node_class, method)
        build_where_chain(opts, rest) do |rel|
          case rel
          when Arel::Nodes::In, Arel::Nodes::Equality
            arel_node_class.new(rel.left, rel.right)
          else
            raise ArgumentError, "Invalid argument for .where.#{method}(), got #{rel.class}"
          end
        end
      end

      def equality_to_function(function_name, opts, rest)
        build_where_chain(opts, rest) do |rel|
          case rel
          when Arel::Nodes::Equality
            Arel::Nodes::Equality.new(rel.right, Arel::Nodes::NamedFunction.new(function_name, [rel.left]))
          else
            raise ArgumentError, "Invalid argument for .where.#{function_name.downcase}(), got #{rel.class}"
          end
        end
      end
    end
  end
end

