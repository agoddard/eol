# Roles grant privileges (unless specifically revoked from a member).
#
# Note that there are no "universal" Roles. Every role is attached to a community.  And, in fact, there are a few "default"
# roles that are assigned to a community when it's created... but they can be changed later.  So there may be what appear
# like a lot of duplicates in the roles table.  But each community has full control of that role, so they are in fact
# separate entities.  See Role#add_defaults_to_community.
class Role < ActiveRecord::Base

  belongs_to :community

  has_and_belongs_to_many :privileges
  has_and_belongs_to_many :members

  validates_presence_of :title

  def self.curator
    cached_with_local_cache('curator') do
      Role.find_by_community_id_and_title(Community.special.id, $CURATOR_ROLE_NAME)
    end
  end
  def self.moderator
    logger.error "Called deprecated Role#moderator.  This will be removed eventually.  Stop it."
    cached_with_local_cache(:title, 'Moderator')
  end
  def self.administrator
    cached_with_local_cache('administrator') do
      Role.find_by_community_id_and_title(Community.special.id, $ADMIN_ROLE_NAME)
    end
  end

  # TODO - with master?
  # Returns the list of new roles, SORTED BY THE NUMBER OF PRIVILEGES THEY HAVE.  ...This is so you know that the .first
  # member of the returned array is the owner.
  def self.add_defaults_to_community(community)
    raise "You didn't specify a community" unless community
    default_roles = {'Admin' => 20}
    new_roles = []
    default_roles.keys.each do |key|
      unless self.exists?(['title = ? and community_id = ?', key, community.id])
        new_roles << self.create(:community_id => community.id, :title => key)
        # TODO - we really should change Language#english to Language#default and have it set in a config file.
        # TODO - this is stupid, but migrations break because Language (the model) doesn't point to the right DB when
        # this runs, so it is undefined after recreating the DB (in which case we hardly need it anyway):
        begin
          new_roles.last.privileges = Privilege.find(:all, :conditions => ["special != 1 and level <= ?", default_roles[key]])
        rescue ActiveRecord::StatementInvalid => e
          # Do nothing; this only happens when devs recreate databases and hardly matters, then.
        end
        new_roles.last.save!
      end
    end
    community.roles += new_roles unless new_roles.empty?
    community.roles.sort {|a,b| b.privileges.length <=> a.privileges.length }
  end

  def add_privilege(priv)
    privileges << priv
  end

  def remove_privilege(priv)
    privileges.delete(priv)
  end

  def can?(priv)
    self.privileges.include? priv
  end

  # We want to do this more efficiently than Rails easily allows:
  def count
    v = self.connection.execute("SELECT count(*) as c FROM members_roles WHERE role_id = #{self.id}").all_hashes[0]['c'].to_i
  end

end
