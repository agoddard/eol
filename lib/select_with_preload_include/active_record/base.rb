module ActiveRecord
  class Base
    class << self
      private
        def find_every(options)
          include_associations = merge_includes(scope(:find, :include), options[:include])
          
          if include_associations.any? && references_eager_loaded_tables?(options)
            records = find_with_associations(options)
          else
            records = find_by_sql(construct_finder_sql(options))
            if include_associations.any?
              # EOL: the only change in this method is to send along the select option
              preload_associations(records, include_associations, {:select => options[:select]})
            end
          end
          
          records.each { |record| record.readonly! } if options[:readonly]
          
          records
        end
        
        def construct_finder_sql(options)
          scope = scope(:find)
          
          # puts "<<<<<<<<<<<<<"
          # pp options
          # EOL: this block was added
          #   only use selects that pertain to this table
          modified_select = options[:select]
          if options[:select] && options[:joins].blank?
            # add in needed select fields. Associations will require a foreign key or primary
            # key to be included - so add these even if they are not in the original :select statement
            options[:select] = add_association_keys_to_select(options)
            
            # remove any fields not pertaining to this table
            select_table_fields = split_table_fields(options[:select], {:delete_other_model_selects => true})
            modified_select = reform_select_from_fields(select_table_fields.uniq)
          end
          
          #EOL: changed options[:select] to modified_select in the line below
          sql  = "SELECT #{modified_select || (scope && scope[:select]) || default_select(options[:joins] || (scope && scope[:joins]))} "
          sql << "FROM #{options[:from]  || (scope && scope[:from]) || quoted_table_name} "
        
          add_joins!(sql, options[:joins], scope)
          add_conditions!(sql, options[:conditions], scope)
        
          add_group!(sql, options[:group], options[:having], scope)
          add_order!(sql, options[:order], scope)
          add_limit!(sql, options, scope)
          add_lock!(sql, options, scope)
        
          sql
        end
    end
  end
end  