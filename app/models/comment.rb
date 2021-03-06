# Comments are just what you expect... but it would be better if you thought of them instead (or additionally) as a
# kind of "User-entered activity log", because they are viewed inextricably with the activity logs.
# ...Alternatively, you could think of activity logs as automatically-posted comments with some intellgence built
# into them.  Whatever works for you.  ...The point is, there two concepts are tightly intertwined.  In terms of the
# code, you will need comments to be shown with the activity_log code, though.
#
# Comments are polymorphically related to many kind of models.  At the time of this writing, it includes Taxon
# Concepts, Data Objects, Communities, Collections, and Users... but could be extended in the future.
#
# Comments can be hidden (by those with Community#special's Privilege#hide_comments).
#
# Note that we presently have no way to edit comments, and won't add this feature until it becomes important.
class Comment < ActiveRecord::Base

  belongs_to :user # always always posted by a user.
  belongs_to :parent, :polymorphic => true
  has_one :curator_activity_log # Because you can post a comment along with activity, and we want the two to have a
  # relationship in the DB, so we can report on it to content partners.

  # I *do not* have any idea why Time.now wasn't working (I assume it was a time-zone thing), but this works:
  named_scope :visible, lambda { { :conditions => ['visible_at <= ?', 0.seconds.from_now] } }

  before_create :set_visible_at, :set_from_curator

  validates_presence_of :body, :user

  attr_accessor :vetted_by

  def self.for_feeds(type = :all, taxon_concept_id = nil, max_results = 50)
    return [] if taxon_concept_id.nil?
    min_date = 30.days.ago.strftime('%Y-%m-%d')
    comments_hash = SpeciesSchemaModel.connection.execute(ActiveRecord::Base.sanitize_sql_array(["
      ( SELECT c.id, c.body description, he_children.taxon_concept_id, 'Comment' data_type_label, c.created_at, n.string scientific_name
        FROM hierarchy_entries he_parent
          JOIN hierarchy_entries he_children
            ON (he_children.lft BETWEEN he_parent.lft AND he_parent.rgt
                AND he_parent.rgt!=0
                AND he_parent.hierarchy_id=he_children.hierarchy_id)
          JOIN names n ON (he_children.name_id=n.id)
          JOIN data_objects_hierarchy_entries dohe ON (he_children.id=dohe.hierarchy_entry_id)
          JOIN curated_data_objects_hierarchy_entries cdohe ON
            (dohe.data_object_id = cdohe.data_object_id
              AND dohe.hierarchy_entry_id = cdohe.hierarchy_entry_id)
          JOIN data_objects do ON (dohe.data_object_id=do.id)
          JOIN data_objects do1 ON (do.guid=do1.guid)
          JOIN #{Comment.full_table_name} c ON(c.parent_id=do.id)
        WHERE he_parent.taxon_concept_id = ?
        AND do1.published=1
        AND c.parent_type='DataObject'
        AND c.created_at > ?
      ) UNION (
        SELECT c.id, c.body description, he_children.taxon_concept_id, 'Comment' data_type_label, c.created_at, n.string scientific_name
        FROM hierarchy_entries he_parent
          JOIN hierarchy_entries he_children
            ON (he_children.lft BETWEEN he_parent.lft AND he_parent.rgt
                AND he_parent.rgt!=0
                AND he_parent.hierarchy_id=he_children.hierarchy_id)
          JOIN names n ON (he_children.name_id=n.id)
          JOIN #{Comment.full_table_name} c
            ON(c.parent_id=he_children.taxon_concept_id AND c.parent_type='TaxonConcept')
        WHERE he_parent.taxon_concept_id = ?
        AND c.created_at > ?
      )", taxon_concept_id, min_date, taxon_concept_id, min_date])).all_hashes.uniq

    comments_hash.sort! do |a, b|
      b['created_at'] <=> a['created_at']
    end

    return [] if comments_hash.blank?
    return comments_hash[0..max_results]
  end

  def self.all_by_taxon_concept_recursively(tc)
    dato_ids = tc.all_data_objects.map {|dato| dato.id}
    return [] if dato_ids.empty?
    children_comments = Comment.find_by_sql("
      SELECT comments.*
        FROM hierarchy_entries he_parent
        JOIN hierarchy_entries he_child ON (he_parent.id=he_child.parent_id)
        JOIN comments ON (comments.parent_id = he_child.taxon_concept_id AND comments.parent_type = 'TaxonConcept')
        JOIN hierarchies h ON (he_parent.hierarchy_id=h.id)
        WHERE he_parent.taxon_concept_id = #{tc.id}
        AND browsable=1
    ")
    sql = "SELECT * FROM comments WHERE (parent_id = #{tc.id} AND parent_type = 'TaxonConcept')"
    unless dato_ids.empty?
      sql += " OR (parent_id IN (#{dato_ids.join(',')}) AND parent_type = 'DataObject')"
    end
    Comment.find_by_sql(sql) + children_comments
  end


  # Comments can be hidden.  This method checks to see if a non-curator can see it:
  def visible?
    return false if visible_at.nil?
    return visible_at <= Time.now
  end

  # the description or name of the parent item (i.e. the name of the species or description of the object)
  def parent_name
    return case self.parent_type
      when 'TaxonConcept' then parent.entry.name.string
      when 'DataObject'   then parent.description
      when 'Community'    then parent.name
      when 'Collection'   then parent.name
      else self.parent_type
      end
  end

  def taxa_comment?
    return parent.is_a? TaxonConcept
  end

  def image_comment?
    return(parent.is_a?(DataObject) and parent.image?)
  end

  def text_comment?
    return(parent.is_a?(DataObject) and parent.text?)
  end

  # the image url being commented on, if it's an image
  def parent_image_url
    return_url = case self.parent_type
     when 'DataObject' then
        d=DataObject.find_by_id(self.parent_id)
        d.image? ? d.smart_thumb : ''
     else ''
    end
    return return_url
  end

  # the url of the parent object (taxon concept or data object)
  def parent_url
    return_url = case self.parent_type
     when 'TaxonConcept' then "/pages/#{self.parent_id}"
     when 'DataObject'   then "/data_objects/#{self.parent_id}"
     else ''
    end
    return return_url
  end

  # A friendly version of the parent name (e.g. "Image", "Taxon Concept", etc.)
  #
  # DO *NOT* COMPARE THIS STRING. It is subject to change.  Use the image_comment?, taxa_comment?, and text_comment?
  # methods instead.
  def parent_type_name
    return_name = case self.parent_type
     when 'TaxonConcept' then
        'page'
     when 'DataObject' then
        d=DataObject.find_by_id(self.parent_id)
        d.nil? ? '' : d.data_type.label.downcase
     else ''
    end
    return return_name
  end

  # Test if the parent object (DataObject or TaxonConcept) can be curated by a user:
  def is_curatable_by? by
    parent.is_curatable_by?(by)
  end

  def show(by)
    self.vetted_by = by if by
    self.update_attribute :visible_at, Time.now unless visible_at
  end

  def hide(by)
    self.vetted_by = by if by
    self.update_attribute :visible_at, nil
  end

  # aliases to satisfy curation
  alias vetted? visible?
  alias vet    show
  alias unvet  hide

  # Pagination uses this method to check for a default pagination size:
  def self.per_page
    10
  end

  def taxon_concept_id
    return_t_c = case self.parent_type
     when 'TaxonConcept' then parent.id
     when 'DataObject'   then parent.get_taxon_concepts(:published => :preferred)[0].id
     else nil
    end
    raise "Don't know how to handle a parent type of #{self.parent_type} (or t_c was nil)" if return_t_c.nil?
    return return_t_c
  end

private

  # Run when a comment is created, to ensure it is visible by default:
  def set_visible_at
    self.visible_at ||= Time.now
  end

  def set_from_curator
    self.from_curator = is_curatable_by?(user) if self.from_curator.nil?
    return self.from_curator.to_s
  end

end

