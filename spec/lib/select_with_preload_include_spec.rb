require File.dirname(__FILE__) + '/../spec_helper'

describe 'Select with Preload Include' do
  before :all do
    truncate_all_tables
    load_foundation_cache
    @taxon_concept = build_taxon_concept()
    @last_data_object = DataObject.last
    @last_agent = Agent.last
    ContentPartner.gen(:agent => @last_agent)
  end
  
  it 'should be able to select .*' do
    d = DataObject.find(:last, :select => "data_objects.created_at, vetted.*", :include => :vetted)
    d.vetted.class.should == Vetted
    d.vetted.label.should == @last_data_object.vetted.label
    d.vetted.created_at.should == @last_data_object.vetted.created_at
    d.vetted.updated_at.should == @last_data_object.vetted.created_at
  end
  
  it 'should default select fields to primary table' do
    d = DataObject.find(:last, :select => "created_at, vetted.updated_at", :include => :vetted)
    d.created_at.should == @last_data_object.created_at
    d.updated_at.should == nil
    d.vetted.created_at.should == nil
    d.vetted.updated_at.should == @last_data_object.vetted.updated_at
  end
  
  it 'should be able to select from a belongs_to association' do
    d = DataObject.find(:last, :select => "data_objects.created_at, vetted.created_at", :include => :vetted)
    d.class.should == DataObject
    d.id.should == @last_data_object.id                       # grab the primary key any time there's an include
    d.vetted_id.should == @last_data_object.vetted_id         # we need to grab the foreign_key of :belongs_to
    d.created_at.should == @last_data_object.created_at       # should have the field asked for
    d.updated_at.should == nil                                # shouldn't have a field not asked for
    d.updated_at.should_not == @last_data_object.updated_at   # should have the field asked for
    
    d.vetted.class.should == Vetted
    d.vetted.created_at.should == @last_data_object.vetted.created_at
    d.vetted.updated_at.should == nil
    d.vetted.updated_at.should_not == @last_data_object.vetted.updated_at
  end
  
  it 'should be able to select from a has_one association' do
    a = Agent.find(:last, :select => "agents.created_at, users.created_at", :include => :user)
    a.class.should == Agent
    a.id.should == @last_agent.id                       # we grab the primary key any time there's an include
    a.created_at.should == @last_agent.created_at       # should have the field asked for
    a.updated_at.should == nil                          # shouldn't have a field not asked for
    a.updated_at.should_not == @last_agent.updated_at   # should have the field asked for
    
    a.user.class.should == User
    a.user.agent_id.should == @last_agent.id            # we need to grab the foreign_key of :has_one
    a.user.created_at.should == @last_agent.user.created_at
    a.user.updated_at.should == nil
    a.user.updated_at.should_not == @last_agent.user.updated_at
  end
  
  it 'should be able to select from a has_many association' do
    d = DataObject.find(:last, :select => "data_objects.created_at, feed_data_objects.created_at", :include => :feed_data_objects)
    d.class.should == DataObject
    d.id.should == @last_data_object.id                       # we grab the primary key any time there's an include
    d.created_at.should == @last_data_object.created_at       # should have the field asked for
    d.updated_at.should == nil                                # shouldn't have a field not asked for
    d.updated_at.should_not == @last_data_object.updated_at   # should have the field asked for
    
    d.feed_data_objects.class.should == Array
    d.feed_data_objects[0].class.should == FeedDataObject
    d.feed_data_objects[0].data_object_id.should == @last_data_object.id   # we need to grab the foreign_key of :has_many
    d.feed_data_objects[0].created_at.should == @last_data_object.feed_data_objects[0].created_at
    d.feed_data_objects[0].data_type_id?.should == false
    @last_data_object.feed_data_objects[0].data_type_id?.should == true
  end
  
  it 'should be able to select from a has_many through association' do
    d = DataObject.find(:last, :select => "data_objects.created_at, harvest_events.began_at", :include => :harvest_events)
    d.class.should == DataObject
    d.id.should == @last_data_object.id                       # we grab the primary key any time there's an include
    d.created_at.should == @last_data_object.created_at       # should have the field asked for
    d.updated_at.should == nil                                # shouldn't have a field not asked for
    d.updated_at.should_not == @last_data_object.updated_at   # should have the field asked for
    
    d.harvest_events.class.should == Array
    d.harvest_events[0].class.should == HarvestEvent
    d.harvest_events[0].id.should == @last_data_object.harvest_events[0].id   # we grab the primary key any time there's an include
    d.harvest_events[0].began_at.should == @last_data_object.harvest_events[0].began_at
    d.harvest_events[0].completed_at?.should == false
    @last_data_object.harvest_events[0].completed_at?.should == true
    
    # the through models will also get loaded with all attributes
    d.data_objects_harvest_events.class.should == Array
    d.data_objects_harvest_events[0].class.should == DataObjectsHarvestEvent
    d.data_objects_harvest_events[0].harvest_event_id.should == @last_data_object.data_objects_harvest_events[0].harvest_event_id
    d.data_objects_harvest_events[0].guid.should == @last_data_object.data_objects_harvest_events[0].guid
    d.data_objects_harvest_events[0].status_id.should == @last_data_object.data_objects_harvest_events[0].status_id
  end
end
