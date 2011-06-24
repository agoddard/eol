module ActiveRecord
  class Base
    class << self

      def index_with_solr(options={})
        # remove any existing callbacks in case we want to redefine the index fields
        remove_index_with_solr

        after_save :add_to_index
        before_destroy :remove_from_index
        options[:keywords] ||= []
        options[:full_text] ||= []

        define_method(:remove_from_index) do
          begin
            solr_connection = SolrAPI.new($SOLR_SERVER, $SOLR_SITE_SEARCH_CORE)
          rescue Errno::ECONNREFUSED => e
            puts "** WARNING: Solr connection failed."
            return nil
          end
          solr_connection.delete_by_query("resource_type:#{self.class.to_s} AND resource_id:#{self.id}")
        end

        define_method(:add_to_index) do
          remove_from_index
          begin
            solr_connection = SolrAPI.new($SOLR_SERVER, $SOLR_SITE_SEARCH_CORE)
          rescue Errno::ECONNREFUSED => e
            puts "** WARNING: Solr connection failed."
            return nil
          end
          
          # making some exceptions for the special community and its collection which are not to be returned in searches
          return if self.class == Community && self == Community.special
          return if self.class == Collection && self.community_id == Community.special.id
          
          params = {
            'resource_type'       => self.class.to_s,
            'resource_id'         => self.id,
            'resource_unique_key' => "#{self.class}_#{self.id}"
          }
          params['date_created'] = self.created_at.solr_timestamp rescue nil
          params['date_modified'] = self.updated_at.solr_timestamp rescue nil
          
          if self.class == DataObject && self.data_type
            data_type_label = self.is_video? ? 'Video' : self.data_type.label('en')
            params['resource_type'] = [self.class.to_s, data_type_label]
          end
          
          options[:keywords] ||= []
          options[:keywords].each do |field_or_method|
            if self.respond_to?(field_or_method)
              return_value = self.method(field_or_method).call
              if return_value.class == String
                self.class.submit_keyword_to_solr(solr_connection, params, return_value, field_or_method)
              elsif return_value.class == Hash
                keyword_type = return_value[:keyword_type] || field_or_method
                return_value[:keywords].each do |keyword|
                  self.class.submit_keyword_to_solr(solr_connection, params, keyword, keyword_type, :language => return_value[:language])
                end
              elsif return_value.class == Array
                return_value.each do |rv|
                  keyword_type = rv[:keyword_type] || field_or_method
                  rv[:keywords].each do |keyword|
                    self.class.submit_keyword_to_solr(solr_connection, params, keyword, keyword_type, :language => rv[:language])
                  end
                end
              end
            else
              raise "NoMethodError: undefined method `#{field_or_method}' for #{self.class.to_s}"
            end
          end

          options[:fulltexts] ||= []
          options[:fulltexts].each do |field_or_method|
            if self.respond_to?(field_or_method)
              self.class.submit_keyword_to_solr(solr_connection, params, self.method(field_or_method).call, field_or_method, :fulltext => true)
            else
              raise "NoMethodError: undefined method `#{field_or_method}' for #{self.class.to_s}"
            end
          end
        end
      end

      def submit_keyword_to_solr(solr_connection, params, keyword, keyword_type, options={})
        options[:language] ||= 'en'
        params['keyword'] = keyword
        params['keyword_type'] = keyword_type
        params['full_text'] = true if options[:is_fulltext]
        params['language'] = options[:language]
        solr_connection.create(params)
      end

      def remove_index_with_solr
        # these methods may not exist yet and that's OK
        remove_method :add_to_index rescue nil
        remove_method :remove_from_index rescue nil
        self.after_save.delete_if{ |callback| callback.method == :add_to_index}
        self.before_destroy.delete_if{ |callback| callback.method == :remove_from_index}
      end
    end
  end
end