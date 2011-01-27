unless data_object.blank?
  xml.dataObject do
    xml.dc :identifier, data_object.guid
    xml.dataType data_object.data_type.label
    
    unless minimal
      xml.mimeType data_object.mime_type.label if data_object.mime_type
    
      for ado in data_object.agents_data_objects
        xml.agent ado.agent.full_name, :homepage => ado.agent.homepage, :role => ado.agent_role.label.downcase
      end
    
      xml.dcterms :created, data_object.object_created_at unless data_object.object_created_at.blank?
      xml.dcterms :modified, data_object.updated_at unless data_object.updated_at.blank?
      xml.dc :title, data_object.object_title unless data_object.object_title.blank?
      xml.dc :language, data_object.language.iso_639_1 if data_object.language
      xml.license data_object.license.source_url if data_object.license
      xml.dc :rights, data_object.rights_statement unless data_object.rights_statement.blank?
      xml.dcterms :rightsHolder, data_object.rights_holder unless data_object.rights_holder.blank?
      xml.dcterms :bibliographicCitation, data_object.bibliographic_citation unless data_object.bibliographic_citation
      xml.dc :source, data_object.source_url unless data_object.source_url.blank?
    end
    
    xml.subject object_hash.info_items[0].schema_value unless data_object.info_items.blank?
    
    unless minimal
      xml.dc :description, data_object.description unless data_object.description.blank?
      xml.mediaURL data_object.object_url unless data_object.object_url.blank?
      xml.mediaURL DataObject.image_cache_path(data_object.object_cache_url, :large) unless data_object.object_cache_url.blank?
      xml.thumbnailURL data_object.thumbnail_url unless data_object.thumbnail_url.blank?
      xml.location data_object.location unless data_object.location.blank?
    
      unless data_object.latitude==0.0 && data_object.longitude==0.0 && data_object.altitude==0.0
        xml.geo :Point do
          xml.geo :lat, data_object.latitude unless data_object.latitude == 0.0
          xml.geo :long, data_object.longitude unless data_object.longitude == 0.0
          xml.geo :alt, data_object.altitude unless data_object.altitude == 0.0
        end
      end
    
      for ref in data_object.refs
        xml.reference ref.full_reference
      end
    end
  end
end
