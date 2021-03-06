class Taxa::NamesController < TaxaController

  before_filter :instantiate_taxon_concept
  before_filter :preload_core_relationships_for_names

  # Default tab: related names
  def show
    if @dropdown_hierarchy_entry
      @related_names = TaxonConcept.related_names(:hierarchy_entry_id => @dropdown_hierarchy_entry_id)
    else
      @related_names = TaxonConcept.related_names(:taxon_concept_id => @taxon_concept.id)
    end
    @assistive_section_header = I18n.t(:assistive_names_related_header)
    current_user.log_activity(:viewed_taxon_concept_names_related_names, :taxon_concept_id => @taxon_concept.id)
  end

  def synonyms
    associations = { :published_hierarchy_entries => [ :name, { :scientific_synonyms => [ :synonym_relation, :name ] } ] }
    options = { :select => { :hierarchy_entries => [ :id, :name_id, :hierarchy_id, :taxon_concept_id ],
                           :names => [ :id, :string ],
                           :synonym_relations => [ :id ] } }
    TaxonConcept.preload_associations(@taxon_concept, associations, options )
    @assistive_section_header = I18n.t(:assistive_names_synonyms_header)
    current_user.log_activity(:viewed_taxon_concept_names_synonyms, :taxon_concept_id => @taxon_concept.id)
  end

  def common_names
    unknown = Language.unknown.label # Just don't want to look it up every time.
    if @dropdown_hierarchy_entry
      names = EOL::CommonNameDisplay.find_by_hierarchy_entry_id(@dropdown_hierarchy_entry.id)
    else
      names = EOL::CommonNameDisplay.find_by_taxon_concept_id(@taxon_concept.id)
    end
    names = names.select {|n| n.language_label != unknown}
    @common_names = names
    # only curators need access to a language list - for adding new common names
    @languages = build_language_list if current_user.is_curator?
    @assistive_section_header = I18n.t(:assistive_names_common_header)
    current_user.log_activity(:viewed_taxon_concept_names_common_names, :taxon_concept_id => @taxon_concept.id)
  end

private

  def preload_core_relationships_for_names
    includes = [
      { :published_hierarchy_entries => [ :name, { :hierarchy => :agent }, :hierarchies_content, :vetted ] }]
    selects = {
      :taxon_concepts => '*',
      :hierarchy_entries => [ :id, :rank_id, :identifier, :hierarchy_id, :parent_id, :published, :visibility_id, :lft, :rgt, :taxon_concept_id, :source_url ],
      :names => [ :string, :italicized, :canonical_form_id, :ranked_canonical_form_id ],
      :hierarchies => [ :agent_id, :browsable, :outlink_uri, :label ],
      :hierarchies_content => [ :content_level, :image, :text, :child_image, :map, :youtube, :flash ],
      :vetted => :view_order,
      :agents => '*' }
    @taxon_concept = TaxonConcept.core_relationships(:include => includes, :select => selects).find_by_id(@taxon_concept.id)
    @hierarchies = @taxon_concept.published_hierarchy_entries.collect{|he| he.hierarchy if he.hierarchy.browsable? }.uniq
    # TODO: Eager load hierarchy entry agents?
    @dropdown_hierarchy_entry_id = params[:hierarchy_entry_id]
    @dropdown_hierarchy_entry = HierarchyEntry.find_by_id(@dropdown_hierarchy_entry_id) rescue nil
    @hierarchy_entries_to_offer = @taxon_concept.published_hierarchy_entries
  end
end
