class Administrator::UserDataObjectController < AdminController  

  layout 'left_menu'

  before_filter :set_layout_variables

  def index

    @page_title = 'User Submitted Text'
 
    @user_id=params[:user_id] || 'All'
    @user_list=User.users_with_submitted_text
    
    @object_ids = UsersDataObject.get_user_submitted_data_object_ids(@user_id)
    @obj_toc_info = DataObject.get_toc_info(@object_ids)
    
    if(@user_id == 'All') then    
      @comments=UsersDataObject.paginate(:order=>'id desc',:include=>:user,:page => params[:page])
      @comment_count=UsersDataObject.count()
    else
      @comments=UsersDataObject.paginate(:conditions=>['user_id = ?',@user_id], :order=>'id desc',:include=>:user,:page => params[:page])
      @comment_count=UsersDataObject.count(:conditions=>['user_id = ?',@user_id])      
    end
    
  end
  
private

  def set_layout_variables
    @page_title = $ADMIN_CONSOLE_TITLE
    @navigation_partial = '/admin/navigation'
  end

end
