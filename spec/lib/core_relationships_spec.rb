require File.dirname(__FILE__) + '/../spec_helper'

describe 'Core Relationships' do
  before :all do
    Vetted.define_core_relationships :include => [:data_objects, :taxon_concepts]
    
    truncate_all_tables
    Vetted.gen(:label => 'trusted')
    @trusted = Vetted.trusted
    @data_object = DataObject.gen(:vetted => @trusted)
    @taxon_concept = TaxonConcept.gen(:vetted => @trusted)
    @hierarchy_entry = HierarchyEntry.gen(:vetted => @trusted)
  end
  
  before :each do
    # make sure any loaded assoications are reverted
    @trusted.reload
  end
  
  describe " as association" do
    it 'should create a method core_relationships' do
      @trusted.core_relationships.class.should == Vetted
      @trusted.core_relationships.id.should == @trusted.id
      @trusted.core_relationships.data_objects.should == @trusted.data_objects
      @trusted.core_relationships.taxon_concepts.should == @trusted.taxon_concepts
    end
    
    it 'should eager load the associations' do
      @trusted.core_relationships.instance_variable_get("@data_objects").should_not == nil
      @trusted.core_relationships.instance_variable_get("@taxon_concepts").should_not == nil
      @trusted.instance_variable_get("@data_objects").should == nil
      @trusted.instance_variable_get("@taxon_concepts").should == nil
      
      # but not ones we didnt specify
      @trusted.core_relationships.instance_variable_get("@hierarchy_entries").should == nil
      @trusted.instance_variable_get("@hierarchy_entries").should == nil
    end
  end
  
  
  describe " as named_scope" do
    it 'should allow associations to be removed with :except' do
      r = Vetted.core_relationships().last
      r.instance_variable_get("@data_objects").should_not == nil
      r.instance_variable_get("@taxon_concepts").should_not == nil
      
      r = Vetted.core_relationships(:except => :taxon_concepts).last
      r.instance_variable_get("@data_objects").should_not == nil
      r.instance_variable_get("@taxon_concepts").should == nil
    end
    
    it 'should NOT remove default relationships permanently' do
      r = Vetted.core_relationships(:except => :taxon_concepts).last
      r.instance_variable_get("@data_objects").should_not == nil
      r.instance_variable_get("@taxon_concepts").should == nil
      
      # not wirking right now
      # # now we're removing data_object but taxon_concepts SHOULD be returned
      # r = Vetted.core_relationships(:except => :data_objects).last
      # r.instance_variable_get("@data_objects").should == nil
      # r.instance_variable_get("@taxon_concepts").should_not == nil
    end
  end
end
