# This is similar to the select_with_include gem: http://code.google.com/p/ar-select-with-include/
# As of Rails 2.1 eager loading associations happen in separate queries:
#   see: http://rails.rubyonrails.org/classes/ActiveRecord/AssociationPreload/ClassMethods.html
# This extentions is mean to allow a select statement when using the :include option on finds
## For Example:
##   DataObject.find(:last,
##                   :select => 'data_objects.id, data_objects.created_at, vetted.label, data_types.*',
##                   :include => [:vetted, :data_type])

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
          
          # puts "???????????????????"
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
        
        def add_association_keys_to_select(options)
          select_table_fields = split_table_fields(options[:select])
          
          # check which associations from this model are included
          included_associations = first_level_includes(options[:include])
          #select_table_fields.concat(class_primary_key_fields(self))
          unless included_associations.blank?
            
            select_table_fields.concat(class_primary_key_fields(self))
            
            included_associations.each do |a|
              if r = self.reflections[a]
                if r.macro == :belongs_to
                  select_table_fields << [self.table_name, r.primary_key_name.to_s]
                  select_table_fields.concat(class_primary_key_fields(r.klass))
                elsif r.macro == :has_one
                  select_table_fields << [r.klass.table_name, r.primary_key_name.to_s]
                elsif r.macro == :has_many
                  if r.options[:through] && r.source_reflection
                    select_table_fields.concat(class_primary_key_fields(r.source_reflection.klass))
                  else
                    select_table_fields << [r.klass.table_name, r.primary_key_name.to_s]
                  end
                end
              end
            end
          end
          reform_select_from_fields(select_table_fields.uniq)
        end
        
        def class_primary_key_fields(klass)
          fields = []
          if klass.primary_key.class == Array
            klass.primary_key.each do |pk|
              fields << [klass.table_name, pk.to_s]
            end
          else
            fields << [klass.table_name, klass.primary_key]
          end
          fields
        end
        
        def first_level_includes(include_option)
          includes = []
          if include_option.class == Array
            include_option.each do |inc|
              if inc.class == Hash  # {:user => :favorites}
                includes << inc.keys[0].to_sym
              elsif inc.class == Symbol || inc.class ==  String
                includes << inc.to_sym
              end
            end
          elsif include_option.class == Symbol || include_option.class ==  String
            includes << include_option.to_sym
          end
          includes
        end
        
        # EOL: used to grab only the select fields that to pertain to this table
        def split_table_fields(select_statement, split_options = {})
          return select_statement if select_statement.class != String
          # split user.name, `term`.`definition` into [['user', 'name'], ['term', 'definition']]
          table_fields = []
          select_statement.split(",").each do |tf|
            if m = tf.strip.match(/^`?(\w+|\*)`?\.`?(\w+|\*)`?$/)
              table_fields << [m[1], m[2]]
            elsif m = tf.strip.match(/^(\w+|\*)$/)
              table_fields << [self.table_name, m[1]]
            end
          end
          
          # delete those not for this table
          if split_options[:delete_other_model_selects]
            table_fields.delete_if{|tf| tf[0] != self.table_name}
          end
          table_fields
        end
        
        def reform_select_from_fields(table_fields)
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
        def preload_has_one_association(records, reflection, preload_options={})
          return if records.first.send("loaded_#{reflection.name}?")
          id_to_record_map, ids = construct_id_map(records, reflection.options[:primary_key])
          # EOL: duplicating the options
          options = reflection.options.dup
          records.each {|record| record.send("set_#{reflection.name}_target", nil)}
          if options[:through]
            through_records = preload_through_records(records, reflection, options[:through], {:select => preload_options[:select]})
            through_reflection = reflections[options[:through]]
            through_primary_key = through_reflection.primary_key_name
            unless through_records.empty?
              source = reflection.source_reflection.name
              through_records.first.class.preload_associations(through_records, source)
              if through_reflection.macro == :belongs_to
                rev_id_to_record_map, rev_ids = construct_id_map(records, through_primary_key)
                rev_primary_key = through_reflection.klass.primary_key
                through_records.each do |through_record|
                  add_preloaded_record_to_collection(rev_id_to_record_map[through_record[rev_primary_key].to_s],
                                                     reflection.name, through_record.send(source))
                end
              else
                through_records.each do |through_record|
                  add_preloaded_record_to_collection(id_to_record_map[through_record[through_primary_key].to_s],
                                                     reflection.name, through_record.send(source))
                end
              end
            end
          else
            set_association_single_records(id_to_record_map, reflection.name, find_associated_records(ids, reflection, preload_options), reflection.primary_key_name)
          end
        end
        
        def preload_has_many_association(records, reflection, preload_options={})
          return if records.first.send(reflection.name).loaded?
          # EOL: duplicating the options
          options = reflection.options.dup

          primary_key_name = reflection.through_reflection_primary_key_name
          id_to_record_map, ids = construct_id_map(records, primary_key_name || reflection.options[:primary_key])
          records.each {|record| record.send(reflection.name).loaded}

          if options[:through]
            through_records = preload_through_records(records, reflection, options[:through], {:select => preload_options[:select]})
            through_reflection = reflections[options[:through]]
            unless through_records.empty?
              source = reflection.source_reflection.name
              options[:select] = preload_options[:select]
              through_records.first.class.preload_associations(through_records, source, options)
              through_records.each do |through_record|
                through_record_id = through_record[reflection.through_reflection_primary_key].to_s
                add_preloaded_records_to_collection(id_to_record_map[through_record_id], reflection.name, through_record.send(source))
              end
            end

          else
            set_association_collection_records(id_to_record_map, reflection.name, find_associated_records(ids, reflection, preload_options),
                                               reflection.primary_key_name)
          end
        end
        
        def preload_through_records(records, reflection, through_association, preload_options={})
          through_reflection = reflections[through_association]
          through_primary_key = through_reflection.primary_key_name

          if reflection.options[:source_type]
            interface = reflection.source_reflection.options[:foreign_type]
            # EOL: extending preload options so we can use the :select passed on through
            preload_options[:conditions] = ["#{connection.quote_column_name interface} = ?", reflection.options[:source_type]]
            records.compact!
            records.first.class.preload_associations(records, through_association, preload_options)

            # Dont cache the association - we would only be caching a subset
            through_records = []
            records.each do |record|
              proxy = record.send(through_association)

              if proxy.respond_to?(:target)
                through_records << proxy.target
                proxy.reset
              else # this is a has_one :through reflection
                through_records << proxy if proxy
              end
            end
            through_records.flatten!
          else
            # EOL: passing on the preload_options including :select options
            records.first.class.preload_associations(records, through_association, preload_options)
            through_records = records.map {|record| record.send(through_association)}.flatten
          end
          through_records.compact!
          through_records
        end
        
        def preload_belongs_to_association(records, reflection, preload_options={})
          return if records.first.send("loaded_#{reflection.name}?")
          # EOL: duplicating the options
          options = reflection.options.dup
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

module CompositePrimaryKeys
  module ActiveRecord
    module AssociationPreload
      module ClassMethods
        def preload_belongs_to_association(records, reflection, preload_options={})
          options = reflection.options
          primary_key_name = reflection.primary_key_name.to_s.split(CompositePrimaryKeys::ID_SEP)

          if options[:polymorphic]
            raise AssociationNotSupported, "Polymorphic joins not supported for composite keys"
          else
            # I need to keep the original ids for each record (as opposed to the stringified) so
            # that they get properly converted for each db so the id_map ends up looking like:
            #
            # { '1,2' => {:id => [1,2], :records => [...records...]}}
            id_map = {}

            records.each do |record|
              key = primary_key_name.map{|k| record.send(k)}
              key_as_string = key.join(CompositePrimaryKeys::ID_SEP)

              if key_as_string
                mapped_records = (id_map[key_as_string] ||= {:id => key, :records => []})
                mapped_records[:records] << record
              end
            end


            klasses_and_ids = [[reflection.klass.name, id_map]]
          end

          klasses_and_ids.each do |klass_and_id|
            klass_name, id_map = *klass_and_id
            klass = klass_name.constantize
            table_name = klass.quoted_table_name
            connection = reflection.active_record.connection

            if composite?
              primary_key = klass.primary_key.to_s.split(CompositePrimaryKeys::ID_SEP)
              ids = id_map.keys.uniq.map {|id| id_map[id][:id]}

              where = (primary_key * ids.size).in_groups_of(primary_key.size).map do |keys|
                 "(" + keys.map{|key| "#{table_name}.#{connection.quote_column_name(key)} = ?"}.join(" AND ") + ")"
              end.join(" OR ")

              conditions = [where, ids].flatten
            else
              conditions = ["#{table_name}.#{connection.quote_column_name(primary_key)} IN (?)", id_map.keys.uniq]
            end

            conditions.first << append_conditions(reflection, preload_options)
            
            # EOL: this only change in this method is the inclusion of preload_options[:select] below
            associated_records = klass.find(:all,
              :conditions => conditions,
              :include    => options[:include],
              :select     => preload_options[:select] || options[:select],
              :joins      => options[:joins],
              :order      => options[:order])

            set_association_single_records(id_map, reflection.name, associated_records, primary_key)
          end
        end
      end
    end
  end
end