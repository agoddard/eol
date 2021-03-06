# This model holds references to files that have been uploaded by an administrator for use in the CMS (i.e. pages stored
# in the content_page model).  Examples of files are PDFs, Word Docs, JPGs, etc. that need to be referenced in these page.
# The content is stored on the content server and a reference is kept in this model for ease of locating these files.
class ContentUpload < ActiveRecord::Base

  belongs_to :user
  validates_presence_of :link_name
  validates_presence_of :description
  validates_format_of :link_name, :with => /^[A-Za-z\d_]+$/, :message => "can only be alphanumeric with no spaces"
  validates_uniqueness_of :link_name
  
  has_attached_file :attachment,
    :path => $CONTENT_UPLOAD_DIRECTORY,
    :url => $CONTENT_UPLOAD_PATH,
    :default_url => "/images/blank.gif"

  validates_attachment_presence :attachment  
  validates_attachment_size :attachment, :in => 0..10.0.megabyte

  def attachment_url # friendly_url, uses the content controller, file method
    "/content/file/#{self.link_name}"    
  end

  def ext
    e = self.attributes['attachment_extension'].downcase
    return ".jpg" if e == '.jpeg'
    return e
  end

  def content_server_url # url on content server
    ContentServer.uploaded_content_url(self.attributes['attachment_cache_url'], self.ext)
  end
  
end
