module ActiveRecord
  class Base
    class << self
      private
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
end