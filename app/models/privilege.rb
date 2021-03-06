# Privileges are our sytem for Access Control across the site, but most specifically within communities.
#
# As of this writing, the ability for privileges to be individually assigned to members is actually NOT planned for
# V2, but when asked if we should proceed with them, I (JRice) was told "yes", so I'm keeping them.  That said, for
# the moment, either you are an admin and have privileges, or you aren't and don't.  :)
require 'core_extensions' # Oddly, these aren't loaded in time for tests, and they are needed here for ACLs.
class Privilege < ActiveRecord::Base

  CACHE_ALL_ROWS = true
  uses_translations

  has_many :member_privileges
  has_many :members, :through => 'member_privileges'

  has_and_belongs_to_many :roles

  def self.create_defaults
    # These are for communities:
    create_all_for_type({
      'Delete Community' => 20,           # admins only
      'Grant level 20 Privileges' => 20,
      'Revoke level 20 Privileges' => 20,
      'Edit Community' => 15, # admin
      'Add members' => 10, # some communities will allow users to add themselves; others by admin
      'Remove members' => 10, # admin
      'Grant level 10 Privileges' => 10,
      'Revoke level 10 Privileges' => 10,
      'Edit Collections' => 5, # admins
      'Endorse Collections' => 5 # admins
    })
    # These are for the special community (only; they are not available to others):
    create_all_for_type({
      'Admin' => 20,
      'Technical' => 20,
      'Site CMS' => 18,
      'News Items' => 18,
      'Web Users' => 15,
      'Content Partners' => 15,
      'Usage Reports' => 15,
      'Comments and Tags' => 12,
      'Contact Us Submissions' => 12,
      'View Admin Page' => 12,
      'Vet' => 10,
      'Trusted Author' => 10,
      'Hide Comments' => 10,
      'Rate' => 1
    }, true)
  end

  def self.create_all_for_type(hash, special = false)
    hash.keys.each do |key|
      priv = Privilege.create(:level => hash[key], :special => special)
      # TODO - we really should change Language#english to Language#default and have it set in a config file.
      # TODO - this is stupid, but migrations break because Language (the model) doesn't point to the right DB when
      # this runs, so it is undefined after recreating the DB (in which case we hardly need it anyway):
      begin
        TranslatedPrivilege.create(:name => key, :privilege_id => priv.id, :language_id => Language.english.id)
      rescue ActiveRecord::StatementInvalid => e # Missing table
        priv.name = key
        priv.save!
      end
    end
  end

  def self.all_for_community(community)
    list = if community.special?
      self.all
    else
      self.find(:all, :conditions => ["special = ?", false])
    end
    list.sort_by {|p| p.name }
  end

  def self.method_missing(name, *args, &block)
    found = cached_find_translated(:name, name.to_s.gsub('_', ' ')) # not expensive because of CACHE_ALL_ROWS
    super(name, *args, &block) unless found # We didn't have one; pass this on to super.
    found
  end

  def self.member_editing_privileges
    @@member_editing_privileges ||= [
      Privilege.grant_level_20_privileges,
      Privilege.revoke_level_20_privileges,
      Privilege.grant_level_10_privileges,
      Privilege.revoke_level_10_privileges
    ]
  end

end
