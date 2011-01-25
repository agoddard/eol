module ActiveRecord
  class Base
    private
    def self.define_core_relationships(options = {})
      # add :include
      has_one :core_relationships, :foreign_key => :id, :class_name => self.class_name, :include => options[:include], :select => options[:select]
      
      # in case we remove some here - further instance of this object would default to having that association
      # removed from their details methods
      named_scope :core_relationships, Proc.new { |*my_options|
        named_scope_options = options.dup
        
        if my_options[0] && my_options[0].class == Hash
          proc_options = my_options[0]
          
          named_scope_options[:select] = proc_options[:select] || named_scope_options[:select]
          named_scope_options[:include] = proc_options[:include] || named_scope_options[:include]
          
          if !proc_options[:only].blank?
            if proc_options[:only].class == Symbol
              named_scope_options[:include] = [proc_options[:only]]
            else #array
              named_scope_options[:include] = proc_options[:only]
            end
          elsif !proc_options[:except].blank?
            if proc_options[:except].class == Symbol
              named_scope_options[:include].reject!{|p| p == proc_options[:except] }
            else # array
              named_scope_options[:include].reject!{|p| proc_options[:except].include? p }
            end
          end
        end
        
        # return the possibly modified set of parameters
        named_scope_options
      }
    end
  end
end