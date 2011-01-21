# 
module ActiveRecord
  class Base

    def self.define_core_relationships(params, options = {})
      # need to add :select
      # add :include
      has_one :core_relationships, :foreign_key => :id, :class_name => self.class_name, :include => params
      
      # in case we remove some here - further instance of this object would default to having that association
      # removed from their details methods
      named_scope :core_relationships, Proc.new { |*my_params|
        if my_params[0] && my_params[0].class == Hash
          proc_params = my_params[0]
          if !proc_params[:only].blank?
            if proc_params[:only].class == Symbol
              named_scope_params = [proc_params[:only]]
            else #array
              named_scope_params = proc_params[:only]
            end
          elsif !proc_params[:except].blank?
            if proc_params[:except].class == Symbol
              named_scope_params = params.reject{|p| p == proc_params[:except] }
            else # array
              named_scope_params = params.reject{|p| proc_params[:except].include? p }
            end
          else
            named_scope_params
          end
        else
          named_scope_params = params.uniq
        end
        { :include => named_scope_params }
      }
    end
    
    
    ## Everything from here on out is monkey-patching ActiveRecordto allow :select and :include 
    ## options to be used simultaneously.
    ## For Example:
    ##   DataObject.find(:all,
    ##                   :select => 'data_objects.id, data_objects.created_at, vetted.label, data_types.*',
    ##                   :include => [:vetted, :data_type])
    class << self
      private
        def find_every(options)
          include_associations = merge_includes(scope(:find, :include), options[:include])
          
          if include_associations.any? && references_eager_loaded_tables?(options)
            records = find_with_associations(options)
          else
            records = find_by_sql(construct_finder_sql(options))
            if include_associations.any?
              # EOL: the only change is sending along the select fields
              preload_associations(records, include_associations, {:select => options[:select]})
            end
          end
          
          records.each { |record| record.readonly! } if options[:readonly]
          
          records
        end
        
        def construct_finder_sql(options)
          scope = scope(:find)
          
          # EOL: this block is the only change - only use selects that pertain to this table
          this_model_select = options[:select]
          pp options
          if options[:select] && options[:joins].blank?
            this_model_select = select_fields_for_table(options[:select])
          end
          
          sql  = "SELECT #{this_model_select || (scope && scope[:select]) || default_select(options[:joins] || (scope && scope[:joins]))} "
          sql << "FROM #{options[:from]  || (scope && scope[:from]) || quoted_table_name} "
        
          add_joins!(sql, options[:joins], scope)
          add_conditions!(sql, options[:conditions], scope)
        
          add_group!(sql, options[:group], options[:having], scope)
          add_order!(sql, options[:order], scope)
          add_limit!(sql, options, scope)
          add_lock!(sql, options, scope)
        
          sql
        end
        
        # EOL: used to grab only the select fields that to pertain to this table
        def select_fields_for_table(select_statement)
          return select_statement if select_statement.class != String
          # split the select into [[table_name, field_name], ...]
          table_fields = select_statement.scan(/`?(\w+|\*)`?\.`?(\w+|\*)`?/)
          # delete those not for this table
          table_fields.delete_if{|tf| tf[0] != self.table_name}
          # re-form the select with the remainder
          new_select_fields = []
          table_fields.each do |tf|
            new_tf = "`#{tf[0]}`."
            new_tf += (tf[1] == '*') ? "*" : "`#{tf[1]}`"
            new_select_fields << new_tf
          end
          # return nil instead of empty array
          return nil if new_select_fields.blank?
          new_select_fields.join(",")
        end
    end
  end
  
  module Associations
    private
      module ClassMethods
        private
          # EOL: this method was previously also checking:  || include_eager_select?(options, joined_tables)
          # basically making sure included tables are not referenced in the :include option
          # we're allowing :select with :include so that condition was removed
          def references_eager_loaded_tables?(options)
            joined_tables = joined_tables(options)
            include_eager_order?(options, nil, joined_tables) || include_eager_conditions?(options, nil, joined_tables)
          end
      end
  end
  
  module AssociationPreload
    module ClassMethods
      private
        def preload_belongs_to_association(records, reflection, preload_options={})
          return if records.first.send("loaded_#{reflection.name}?")
          options = reflection.options
          primary_key_name = reflection.primary_key_name
  
          if options[:polymorphic]
            polymorph_type = options[:foreign_type]
            klasses_and_ids = {}
  
            # Construct a mapping from klass to a list of ids to load and a mapping of those ids back to their parent_records
            records.each do |record|
              if klass = record.send(polymorph_type)
                klass_id = record.send(primary_key_name)
                if klass_id
                  id_map = klasses_and_ids[klass] ||= {}
                  id_list_for_klass_id = (id_map[klass_id.to_s] ||= [])
                  id_list_for_klass_id << record
                end
              end
            end
            klasses_and_ids = klasses_and_ids.to_a
          else
            id_map = {}
            records.each do |record|
              key = record.send(primary_key_name)
              if key
                mapped_records = (id_map[key.to_s] ||= [])
                mapped_records << record
              end
            end
            klasses_and_ids = [[reflection.klass.name, id_map]]
          end
          
          klasses_and_ids.each do |klass_and_id|
            klass_name, id_map = *klass_and_id
            next if id_map.empty?
            klass = klass_name.constantize
            
            table_name = klass.quoted_table_name
            primary_key = reflection.options[:primary_key] || klass.primary_key
            column_type = klass.columns.detect{|c| c.name == primary_key}.type
            ids = id_map.keys.map do |id|
              if column_type == :integer
                id.to_i
              elsif column_type == :float
                id.to_f
              else
                id
              end
            end
            conditions = "#{table_name}.#{connection.quote_column_name(primary_key)} #{in_or_equals_for_ids(ids)}"
            conditions << append_conditions(reflection, preload_options)
            associated_records = klass.with_exclusive_scope do
              # EOL: the only change is to allow preload_options[:select] to take precedence
              klass.find(:all, :conditions => [conditions, ids],
                                            :include => options[:include],
                                            :select => preload_options[:select] || options[:select],
                                            :joins => options[:joins],
                                            :order => options[:order])
            end
            set_association_single_records(id_map, reflection.name, associated_records, primary_key)
          end
        end
    end
  end
end