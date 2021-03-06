class SearchController < ApplicationController
  layout 'v2/search'
  
  @@results_per_page = 10
  
  def index
    params[:sort_by] ||= 'score'
    params[:type] ||= ['all']
    params[:type] = ['all'] if params[:type].include?('all')
    @sort_by = params[:sort_by]
    @params_type = params[:type]
    @params_type = ['all'] if @params_type.include?('all')
    @params_type.map!{ |t| t.camelize }
    @querystring = params[:q] || params[:id]
    @page_title  = I18n.t(:search_by_term_page_title, :term => @querystring)
    if @querystring.blank?
      @all_results = empty_paginated_set
      @facets = {}
    else
      search_response = EOL::Solr::SiteSearch.search_with_pagination(@querystring, params.merge({ :per_page => @@results_per_page }))
      @all_results = search_response[:results]
      @facets = search_response[:facets]
      @suggestions = search_response[:suggestions]
      log_search(request)
      current_user.log_activity(:text_search_on, :value => params[:q])
      if @all_results.length == 1 && @all_results.total_entries == 1
        redirect_to_page(@all_results)
      elsif params[:show_all].blank? && @all_results.total_entries > 1 && @all_results.length > 1 &&
        @all_results[0]['score'] > 5 && (@all_results[0]['score'] > (@all_results[1]['score'] * 4))
        redirect_to_page(@all_results, :more_results => true, :params => params)
      end
    end
  end
  
  # there are various object types which can be the only result. This method handles redirecting to all of them
  def redirect_to_page(result_set, options={})
    if options[:more_results]
      modified_params = options[:params].dup
      modified_params.delete(:type) if params[:type] == ['all']
      modified_params.delete(:sort_by) if params[:sort_by] == ['score']
      modified_params.delete_if{ |k, v| ![ :sort_by, :type ].include?(k) }
      flash[:notice] = I18n.t(:flash_notice_redirected_from_search_html_more_results, :search_string => @querystring, :more_results_url => search_path(@querystring, modified_params.merge({ :show_all => true })))
    else
      flash[:notice] = I18n.t(:flash_notice_redirected_from_search_html, :search_string => @querystring)
    end
    result_instance = result_set.first['instance']
    if result_instance.class == Collection
      redirect_to collection_path(result_instance.id)
    elsif result_instance.class == Community
      redirect_to community_path(result_instance.id)
    elsif result_instance.class == DataObject
      redirect_to data_object_path(result_instance.id)
    elsif result_instance.class == User
      redirect_to user_path(result_instance.id)
    elsif result_instance.class == TaxonConcept
      redirect_to taxon_overview_path(result_instance.id)
    end
  end
  
  def empty_paginated_set
    [].paginate(:page => 1, :per_page => @@results_per_page, :total_entries => 0)
  end
  
  # Add an entry to the database desrcibing the fruitfullness of this search.
  def log_search(req)
    logged_search = SearchLog.log(
      { :search_term => @querystring,
        :search_type => @params_type.join(";"),
        :parent_search_log_id => nil,
        :total_number_of_results => @all_results.length },
      req,
      current_user)
    @logged_search_id = logged_search.nil? ? '' : logged_search.id
  end
end
