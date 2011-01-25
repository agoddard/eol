module ActiveRecord
  class Base
    private
    def self.define_core_relationships(options = {})
      # there is already a core_relationships association for whatever reason
      if self.reflections[:core_relationships]
        raise 'Cannot re-define core_relationships'
      end
      has_one :core_relationships, :foreign_key => :id, :class_name => self.class_name, :include => options[:include], :select => options[:select]
      
      # in case we remove some here - further instance of this object would default to having that association
      # removed from their details methods
      named_scope :core_relationships, Proc.new { |*my_options|
        # create a new array of options for each named_scope call
        named_scope_options = options.deepcopy
        
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