require 'spec_helper'

describe Member do

  before(:all) do
    truncate_all_tables
    load_foundation_cache
    @user = User.gen
    @community = Community.gen
    @member = Member.gen(:user => @user, :community => @community)
    @has_role = Role.gen
    @new_role = Role.gen
    @has_privilege = TranslatedPrivilege.gen.privilege
    @new_privilege = TranslatedPrivilege.gen.privilege
    @role_privilege = TranslatedPrivilege.gen.privilege
    @has_role.add_privilege(@role_privilege)
  end

  before(:each) do
    @member.roles = [@has_role]
    MemberPrivilege.delete_all(:member_id => @member.id)
    MemberPrivilege.create!(:privilege_id => @has_privilege.id, :member_id => @member.id)
    @member.save!
  end

  it 'should only be able to add a member to a community once' do
    m = Member.new(:user_id => @user.id, :community_id => @community.id)
    m.valid?.should_not be_true
  end

  it 'should be able to add a role (and identify if it #has_role?)' do
    @member.has_role?(@new_role).should_not be_true
    @member.add_role(@new_role)
    @member.has_role?(@new_role).should be_true
  end

  it 'should be able to remove a role'do
    @member.has_role?(@has_role).should be_true
    @member.remove_role(@has_role)
    @member.has_role?(@has_role).should_not be_true
  end

  it 'should have a single privilege assigned to it (and identify if it #has_privilege?)' do
    @member.has_privilege?(@new_privilege).should_not be_true
    @member.grant_privilege(@new_privilege)
    @member.has_privilege?(@new_privilege).should be_true
  end

  it 'should have multiple privileges assigned to it (and identify if it #has_privilege?)' do
    second_priv = TranslatedPrivilege.gen.privilege
    @member.has_privilege?(@new_privilege).should_not be_true
    @member.grant_privileges([@new_privilege, second_priv])
    @member.has_privilege?(@new_privilege).should be_true
    @member.has_privilege?(second_priv).should be_true
  end

  it 'should be able to revoke a privilege he has, to remove it' do
    @member.revoke_privilege(@has_privilege)
    @member.has_privilege?(@has_privilege).should_not be_true
  end

  it 'should be able to revoke a privilege he doesn\'t have, and identify it with had_privilege_revoked?' do
    @member.revoke_privilege(Privilege.first)
    @member.has_privilege?(Privilege.first).should_not be_true
    @member.had_privilege_revoked?(Privilege.first).should be_true
  end

  describe '#can?' do

    it 'should return false when a privilege has been revoked' do
      @member.revoke_privilege(@has_privilege)
      @member.can?(@has_privilege).should_not be_true
    end

    it 'should return true when a privilege has been specifically assigned to a member' do
      @member.can?(@has_privilege).should be_true
    end

    it 'should return false when a privilege has NOT been assigned to a member or his roles' do
      priv = TranslatedPrivilege.gen.privilege
      @member.can?(priv).should_not be_true
    end

    it 'should return true when a privilege is assigned to a member role' do
      @member.can?(@role_privilege).should be_true
    end

  end

  it 'should decide if a member can edit other members' do
    @member.can_edit_members?.should_not be_true
    @member.grant_privilege(Privilege.grant_level_10_privileges)
    @member.can_edit_members?.should be_true
  end

  it 'should list all privileges (except revoked)' do
    new_priv = TranslatedPrivilege.gen.privilege
    @member.revoke_privilege(new_priv)
    @member.all_sorted_privileges.map {|p| p.name}.should == [@has_privilege, @role_privilege].map {|p| p.name}.sort
  end

  it 'should revoke a privilege even if a member role has it' do
    @member.revoke_privilege(@role_privilege)
    @member.can?(@role_privilege).should_not be_true
  end

  it 'should remove a privilege from member_privileges if it is revoked when the user has that special privilege' do
    new_priv = TranslatedPrivilege.gen.privilege
    @member.grant_privilege(new_priv)
    @member.member_privileges.map {|mp| mp.privilege }.include?(new_priv).should be_true
    @member.revoke_privilege(new_priv)
    @member.member_privileges.map {|mp| mp.privilege }.include?(new_priv).should_not be_true
  end

  it 'should remove a privilege from member_privileges if it is granted when the user had that privilege revoked' do
    new_priv = TranslatedPrivilege.gen.privilege
    @member.revoke_privilege(new_priv)
    @member.member_privileges.map {|mp| mp.privilege }.include?(new_priv).should be_true
    @member.grant_privilege(new_priv)
    @member.member_privileges.map {|mp| mp.privilege }.include?(new_priv).should_not be_true
  end

end
