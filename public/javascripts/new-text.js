// Note that this relies on EOL.TextObjects already existing for a reason; many methods this needs are there.  It should be
// described in text-content.js
$.extend(EOL.TextObjects, {

  // Handle all the behaviours related to adding/editing text.  This may be called several times, so it's extracted to a
  // method:
  init_new_text_behaviors: function() {
    // Submit new text:
    EOL.TextObjects.form().submit(function(e) {
      EOL.TextObjects.submit_text();
      return false;
    });
    // Preview:
    $('input#preview_text').click(function() {
      EOL.TextObjects.preview_text(this);
      return false;
    });
    // Close the add-text window:
    $('#insert_text_popup a.close-button').click(function() {
      $('#insert_text_popup').slideUp();
      EOL.TextObjects.remove_preview();
      return false;
    });
    // Cancel adding text:
    $('input#cancel_edit_text').click(function() {
      EOL.TextObjects.cancel_edit();
      return false;
    });
    // Update the text area when the user changes the TOC Item category:
    $('select#data_objects_toc_category_toc_id').change(function() {
      $.ajax({
        url: $(this).attr('data-change_toc_url'),
        success: function(response) { EOL.TextObjects.show_response_text_and_cleanup(response); },
        data: EOL.TextObjects.form().serialize()
      });
    });
    // Give the user another reference field
    $('div#add_user_text_references input#add_more_user_text_reference').click(function(e) {
      $('#add_user_text_references_input').append('<textarea rows="3" name="references[]" id="references[]" cols="33"/>');
      return false;
    });
  },

  // After an Ajax call, we need to show the response and clean up our mess:
  show_response_text_and_cleanup: function (response) {
    // remove all text objects from page.  It would be better to do this on success, but timing is an issue.
    $('.text_object').slideUp().delay(500).remove();
    // remove warning boxes
    $('div.cpc-content div#unknown-text-warning-box_wrapper').slideUp().delay(500).remove();
    $('div.cpc-content div#untrusted-text-warning-box_wrapper').slideUp().delay(500).remove();
    // Put in the new content:
    $('#insert_text_popup').before(response);
    EOL.TextObjects.init_edit_links();
  },

  // Warn the user that they forgot to add text:
  show_missing_text_error_if_empty: function() {
    // error handling, just make sure there's a description
    textarea_val = $.trim($('textarea#data_object_description').val());
    if(textarea_val == '') {
      $('#missing_text_error').fadeIn().delay(2000).fadeOut();
      return true;
    } else {
      return false;
    }
  },

  // In several cases, we need to know which data object we're currently editing/adding:
  data_object_id: function() {
    return EOL.TextObjects.form().attr('data-data_object_id');
  },

  // For when the user wants to submit added/edited text.
  submit_text: function() {
    if (EOL.TextObjects.show_missing_text_error_if_empty()) return false;
    var id = EOL.TextObjects.data_object_id();
    // If we already have a version of the text, remove it, since we will be re-loading it:
    $('#text_wrapper_'+id).slideUp().delay(500).remove();
    EOL.TextObjects.remove_preview();
    $.ajax({
      url: EOL.TextObjects.form().attr('action'),
      type: 'POST',
      beforeSend: function() { EOL.TextObjects.disable_form(); },
      success: function(response) {
        $('#insert_text_popup').before(response);
        // reset form:  (this may be worth turning in to a global method):
        EOL.TextObjects.form().find('input, textarea').not(':hidden, :button, :submit').val('').removeAttr('checked').removeAttr('selected');
        EOL.TextObjects.init_edit_links();
      },
      complete: function() { $('#insert_text_popup').slideUp(); },
      error: function() { alert("Sorry, there was an error submitting your text.");},
      data: EOL.TextObjects.form().serialize()
    });
  },

  // The text was not submitted, but we want to see what it will look like when it is:
  preview_text: function(button) {
    if (EOL.TextObjects.show_missing_text_error_if_empty()) return false;
    EOL.TextObjects.remove_preview();
    // TODO - the data is hacky ... why isn't it this way in the data-preview_url?
    $.ajax({
      url: $(button).attr('data-preview_url'),
      type: 'POST',
      beforeSend: function() { EOL.TextObjects.disable_form(); },
      success: function(response) {
        $('#insert_text_popup').before(response);
        $('a#edit_text_').remove(); // We don't want them editing the preview text!
        $('#text_wrapper_').slideDown();
      },
      complete: function() { EOL.TextObjects.enable_form(); },
      error: function() { alert("Sorry, there was an error previewing your text.");},
      data: EOL.TextObjects.form().serialize().replace("_method=put&","id="+EOL.TextObjects.data_object_id()+"&")
    });
  },
  
  // In several places, we need to make sure the preview text is removed:
  remove_preview: function() {
    if($('#text_wrapper_')) {
      $('div#text_wrapper_').slideUp().delay(500).remove();
    };
  },

  // This is a little awkward, but after someone was editing their text, we want to make sure it's as-is (as opposed to how
  // it may have been replaced by the preview), so we re-load the text as it actually appears:
  cancel_edit: function() {
    data_object_id = EOL.TextObjects.data_object_id();
    EOL.TextObjects.remove_preview();
    // if the old text still exists on the page, just remove the edit div
    // TODO - does this work?  Can it be said more elegantly?
    if($('#text_wrapper_'+data_object_id).length > 0 || $('#original_toc_id').val() != $('#data_objects_toc_category_toc_id').val()) {
      $('#insert_text_popup').slideUp();
      $("div#text_wrapper_"+data_object_id+"_popup").slideUp(1000).delay(1100).remove();
    } else {
      $.ajax({
        url: $('#edit_data_object_'+data_object_id).attr('action').replace('/data_objects/','/data_objects/get/'),
        success: function(response) { EOL.TextObjects.show_response_text_and_cleanup(response); },
        data: EOL.TextObjects.form.serialize()
      });
      EOL.TextObjects.disable_form();
    }
  },

  // Temporarily prevent the user from sumbitting/previewing the text:
  disable_form: function() {
    EOL.TextObjects.form().find('input[type=submit], input[type=button]').attr('disabled', 'disabled');
    $('#edit_text_spinner').fadeIn();
  },

  // It's okay to work with the form again:
  enable_form: function() {
    EOL.TextObjects.form().find('input[type=submit], input[type=button]').attr('disabled', '');
    $('#edit_text_spinner').fadeOut();
  }

});

$(document).ready(function() {
  EOL.TextObjects.init_new_text_behaviors();
});