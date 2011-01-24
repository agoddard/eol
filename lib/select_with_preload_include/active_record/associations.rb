module ActiveRecord
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
end