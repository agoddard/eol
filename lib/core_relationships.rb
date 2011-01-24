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
  end
end