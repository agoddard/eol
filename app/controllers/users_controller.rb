class UsersController < ApplicationController

  layout :users_layout

  @@objects_per_page = 20

  # GET /users/:id
  def show
    @user = User.find(params[:id])
  end

  def edit
  end
  
  def update
  end
  
  # GET users/new or named route /register
  def new
    @user = User.new
  end

  # POST /users
  def create
    @user = User.create_new(params[:user])
    # give them a validation code and make their account not active by default
    set_validation_code
    while(User.find_by_validation_code(@user.validation_code))
      @user.validation_code.succ!
    end
    @user.active = false
    # set the password and the remote_IP address
    @user.password = @user.entered_password
    @user.remote_ip = request.remote_ip
    if verify_recaptcha && @user.save
      begin
        @user.update_attribute :agent_id, Agent.create_agent_from_user(@user.full_name).id
      rescue ActiveRecord::StatementInvalid
        # Interestingly, we are getting users who already have agents attached to them.  I'm not sure why, but it's causing registration to fail (or seem to; the user is created), and this is bad.
      end
      @user.entered_password = ''
      @user.entered_password_confirmation = ''
      Notifier.deliver_registration_confirmation(@user)
      flash[:notice] = I18n.t(:sign_up_verify_email_notice, :email_address => @user.email)
      redirect_to login_path and return
    else # verify recaptcha failed or other validation errors
      flash[:error] = verify_recaptcha ? I18n.t(:sign_up_unsuccessful_error) : I18n.t(:verification_phrase_did_not_match)
      redirect_to register_path and return
    end
  end

  # users come here from the activation email they receive named route /register/confirm
  def register_confirm
    params[:username] ||= ''
    params[:validation_code] ||= ''
    params[:return_to] = nil
    User.with_master do
      @user = User.find_by_username_and_validation_code(params[:username], params[:validation_code])
    end

    @user.activate unless @user.blank? || @user.active
    @user ||= User.find_by_username(params[:username])
    if @user && @user.active
      flash[:notice] = I18n.t(:sign_up_activation_successful_notice)
      redirect_to login_path
    elsif @user
      set_validation_code
      Notifier.deliver_registration_confirmation(@user)
      flash[:error] = I18n.t(:sign_up_activation_failed_wrong_validation_code_error)
      redirect_to login_path
    else
      @user.blank? # not found please register
      flash[:error] = I18n.t(:sign_up_activation_failed_user_not_found_error)
      redirect_to register_path 
    end
  end
  
  def forgot_password
  end
  
  def reset_password
  end
    
  def objects_curated
    page = (params[:page] || 1).to_i
    current_user.log_activity(:show_objects_curated_by_user_id, :value => params[:id])
    @latest_curator_actions = @user.curator_activity_logs_on_data_objects.paginate_all_by_activity_id(
                                Activity.raw_curator_action_ids,
                                :select => 'curator_activity_logs.*',
                                :order => 'curator_activity_logs.updated_at DESC',
                                :group => 'curator_activity_logs.object_id',
                                :include => [ :activity ],
                                :page => page, :per_page => @@objects_per_page)
    @curated_datos = DataObject.find(@latest_curator_actions.collect{|lca| lca[:object_id]},
                       :select => 'data_objects.id, data_objects.description, data_objects.object_cache_url, ' +
                                  'hierarchy_entries.taxon_concept_id, hierarchy_entries.published, ' +
                                  'taxon_concepts.*, names.italicized' ,
                       :include => [ :vetted, :visibility, :toc_items,
                                     { :hierarchy_entries => [ :taxon_concept, :name ] } ])
    @latest_curator_actions.each do |ah|
      dato = @curated_datos.detect {|item| item[:id] == ah[:object_id]}
      # We use nested include of hierarchy entries, taxon concept and names as a first cheap
      # attempt to retrieve a scientific name.
      # TODO - dato.hierarchy_entries does not account for associations created by (or untrusted by) curators.  That
      # said, this whole method is too much code in a controller and should be re-written, so we are not (right now)
      # going to fix this.  Please create the data in a model and display it in the view.
      dato.hierarchy_entries.each do |he|
        # TODO: Check to see if this is using eager loading or not!
        if he.taxon_concept.published == 1 then
          dato[:_preferred_name_italicized] = he.name.italicized
          dato[:_preferred_taxon_concept_id] = he.taxon_concept_id
          break
        end
      end

      if dato[:_preferred_taxon_concept_id].nil? then
        # Hierarchy entries have not given us a published taxon concept so either the concept has been superceded
        # or its a user submitted data object, either way we go on a hunt for a published taxon concept with some
        # expensive queries.
        tcs = dato.get_taxon_concepts(:published => :preferred)
        tc = tcs.detect{|item| item[:published] == 1}
        # We only add a preferred taxon concept id if we've found a published taxon concept.
        dato[:_preferred_taxon_concept_id] = tc.nil? ? nil : tc[:id]
        # Finally we find a name, first we try cheaper hierarchy entries, if that fails we try through taxon concepts.
        dato[:_preferred_name_italicized] = dato.hierarchy_entries.first.name[:italicized] unless dato.hierarchy_entries.first.nil?
        if dato[:_preferred_name_italicized].nil? then
          tc = tcs.first if tc.nil? # Grab the first unpublished taxon concept if we didn't find a published one earlier.
          dato[:_preferred_name_italicized] = tc.nil? ? nil : tc.quick_scientific_name(:italicized)
        end
      end

      dato[:_description_teaser] = ""
      unless dato.description.blank? then
        dato[:_description_teaser] = Sanitize.clean(dato.description, :elements => %w[b i],
                                                    :remove_contents => %w[table script])
        dato[:_description_teaser] = dato[:_description_teaser].split[0..80].join(' ').balance_tags +
                                     '...' if dato[:_description_teaser].length > 500
      end

    end
  end

  def species_curated
    page = (params[:page] || 1).to_i
    current_user.log_activity(:show_species_curated_by_user_id, :value => params[:id])
    @taxon_concept_ids = @user.taxon_concept_ids_curated.paginate(:page => page, :per_page => @@objects_per_page)
  end

  def comments_moderated
    page = (params[:page] || 1).to_i
    current_user.log_activity(:show_species_comments_moderated_by_user_id, :value => params[:id])
    comment_curation_actions = @user.comment_curation_actions
    @comment_curation_actions = comment_curation_actions.paginate(:page => page, :per_page => @@objects_per_page)
  end

private
  def users_layout
    action_name == 'new' ? 'v2/sessions' : 'v2/users'
  end

  def set_validation_code
    @user.validation_code = Digest::MD5.hexdigest "#{@user.username}#{Time.now.hour}:#{Time.now.min}:#{Time.now.sec}"
  end
end
