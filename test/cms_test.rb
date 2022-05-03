ENV["RACK_ENV"] = "test"

require "minitest/autorun"
require "rack/test"
require "fileutils"

require_relative "../cms"

class CMSTest < Minitest::Test
  include Rack::Test::Methods

  def setup
    FileUtils.mkdir_p(data_path)
  end
  
  def app
    Sinatra::Application
  end

  def session
    last_request.env["rack.session"]
  end

  # provides way to write documents during testing
  def create_document(name, content = "")
    File.open(File.join(data_path, name), "w") do |file|
      file.write(content)
    end
  end

  def admin_session
    { "rack.session" => { user: "admin", pass: "secret", signed_in: true} }
  end

  def test_home_page
    # skip
    create_document("history.txt")
    create_document("about.txt")

    get "/"

    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "<a href=\"/history.txt\"")
  end

  def test_file_output_text
    # skip
    create_document("changes.txt", "Change is constant")

    get "/changes.txt"

    assert_equal(200, last_response.status)
    assert_equal("text/plain", last_response["Content-Type"])
    assert_includes(last_response.body, "Change is constant" )
  end

  def test_file_output_markdown
    # skip
    create_document("mkdown.md", "# Ruby is really clean...")

    get "/mkdown.md"
    
    assert_equal(200, last_response.status)
    assert_equal("text/html;charset=utf-8", last_response["Content-Type"])
    assert_includes(last_response.body, "Ruby is really clean...")
  end

  # Launch Solution
  def test_index
    # skip
    create_document("about.md")
    create_document("changes.txt")

    get "/"

    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_includes last_response.body, "about.md"
    assert_includes last_response.body, "changes.txt"
  end

  # Launch Solution
  def test_viewing_text_document
    # skip
    create_document("history.txt", "Ruby 0.95 released")

    get "/history.txt"

    assert_equal 200, last_response.status
    assert_equal "text/plain", last_response["Content-Type"]
    assert_includes last_response.body, "Ruby 0.95 released"
  end

  def test_nonexistent_file_request
    # skip
    get "/nonexistent.txt"

    assert_equal(302, last_response.status)
    assert_equal("nonexistent.txt does not exist.", session[:message])
  end

  # Launch solution
  def test_document_not_found
    # skip
    get "/notafile.ext" # Attempt to access a nonexistent file
  
    assert_equal 302, last_response.status # Assert that the user was redirected
    assert_equal "notafile.ext does not exist.", session[:message]

    # get last_response["Location"] # Request the page that the user was redirected to
  
    # assert_equal 200, last_response.status
    # assert_includes last_response.body, "notafile.ext does not exist"
  
    # get "/" # Reload the page
    # refute_includes last_response.body, "notafile.ext does not exist" # Assert that our message has been removed
  end

  def test_edit_file_page
    # skip
    create_document("history.txt")

    get "/history.txt/edit", {}, admin_session
    assert_equal(200, last_response.status)
    
    post "/history.txt/edit"
    assert_equal(302, last_response.status)
    assert_equal("history.txt has been updated.", session[:message])
  end

  def test_edit_file_page_not_signed_in
    # skip
    get "/history.txt/edit"
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:message])
  end

  #Launch Solution
  def test_editing_document
    # skip
    create_document("changes.txt")

    get "/changes.txt/edit", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<textarea"
    assert_includes last_response.body, %q(<button type="submit")
  end

  # Launch
  def test_editing_document_signed_out
    # skip
    create_document "changes.txt"

    get "/changes.txt/edit"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  # Launch Solution
  def test_updating_document
    # skip
    post "/changes.txt/edit", { content: "new content" }, admin_session

    assert_equal 302, last_response.status
    assert_equal("changes.txt has been updated.", session[:message])

    get "/changes.txt"
    assert_equal 200, last_response.status
    assert_includes last_response.body, "new content"
  end

  #Launch
  def test_updating_document_signed_out
    # skip
    post "/changes.txt/edit", {content: "new content"}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  def test_new_document
    # skip
    get "/new", {}, admin_session
    assert_equal(200, last_response.status)
    assert_includes(last_response.body, "Add a new document:")
  end

  def test_new_document_no_sign_in
    # skip
    get "/new"
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:message])
  end

  def test_new_document_post_empty
    # skip
    post "/new", { new_file: "" }, admin_session
    assert_equal(422, last_response.status) 
    assert_nil(session[:message])
    assert_includes(last_response.body, "A name is required")
  end

  def test_create_new_document_post_no_signin
    # skip
    post "/new", new_file: "file.txt"
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:message])
  end

  def test_new_document_post_success
    # skip
    post "/new", { new_file: "file.txt" }, admin_session 
    assert_equal(302, last_response.status)
    assert_equal("file.txt was created", session[:message])
    
    get last_response["Location"]
    assert_equal(200, last_response.status)
  end

  def test_new_document_post_success_no_sign_in
    # skip
    post "/new", new_file: "file.txt"
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:message])
  end

  # Launch
  def test_view_new_document_form
    # skip
    get "/new", {}, admin_session

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  def test_view_new_document_form_signed_out
    # skip
    get "/new"

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  # Launch
  def test_create_new_document
    # skip
    post "/new", { new_file: "test.txt" }, admin_session 
    assert_equal 302, last_response.status
    assert_equal("test.txt was created", session[:message])

    # get last_response["Location"]
    # assert_includes last_response.body, "test.txt was created"

    get "/"
    assert_includes last_response.body, "test.txt"
  end

  # Launch
  def test_create_new_document_signed_out
    # skip
    post "/new", {filename: "test.txt"}

    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end

  # Launch
  def test_create_new_document_without_filename
    skip
    post "/new", { new_file: "" }, admin_session
    assert_equal 422, last_response.status
    assert_includes last_response.body, "A name is required"
  end

  def test_file_delete
    skip
    create_document("file.txt")
  
    post "/file.txt/delete", {}, admin_session

    assert_equal(302, last_response.status)
    assert_equal("file.txt was deleted", session[:message])

    get last_response["Location"]

    assert_equal(200, last_response.status)
    assert_nil(session[:message])
    assert_includes(last_response.body, "file.txt was deleted")
  end

  def test_file_delete_no_signin
    skip
    post "/file.txt/delete"
    assert_equal(302, last_response.status)
    assert_equal("You must be signed in to do that.", session[:message])
  end

  # Launch
  def test_deleting_document
    skip
    create_document("test.txt")

    post "/test.txt/delete", {}, admin_session
    assert_equal 302, last_response.status
    assert_equal("test.txt was deleted", session[:message])

    # get last_response["Location"]
    # assert_includes last_response.body, "test.txt was deleted"

    # get "/"
    # refute_includes last_response.body, "test.txt"
  end

  # Launch
  def test_deleting_document_signed_out
    skip
    create_document("test.txt")

    post "/test.txt/delete"
    assert_equal 302, last_response.status
    assert_equal "You must be signed in to do that.", session[:message]
  end




  def test_sign_in_success
    skip
    create_document("users.yml")
    post "/sign_in", user: "admin", pass: "secret" 
    
    assert_equal(302, last_response.status)
    assert_equal("Welcome!", session[:message])

    get last_response["Location"]
    assert_nil(session[:message])
    assert_includes(last_response.body, "Welcome!")

    get "/"
    assert_includes(last_response.body, "Signed in as admin")
  end


  def test_sign_in_new_document
    skip
    post "sign_in", user: "admin", pass: "secret"

    assert_equal(302, last_response.status)
    assert_equal("Welcome!", session[:message])
  
  end
  
  def test_failed_sign_in
    skip
    post "/sign_in", user: "fk", pass: "super_secret" 
    
    assert_equal(422, last_response.status)
    assert_nil(session[:message])
    assert_includes(last_response.body, "Invalid Credentials")
  end

  def test_sign_out
    skip
    post "/sign_in", user: "admin", pass: "secret"
    post "/sign_out"

    assert_equal(302, last_response.status)
    assert_equal("You have been signed out", session[:message])

    get last_response["Location"]
    
    assert_nil(session[:message])
    assert_includes(last_response.body, "You have been signed out")
    assert_includes(last_response.body, "Sign In")
  end

  # Launch
  def test_signin_form
    skip
    # get "/users/signin"
    get "/sign_in"

    assert_equal 200, last_response.status
    assert_includes last_response.body, "<input"
    assert_includes last_response.body, %q(<button type="submit")
  end

  # Launch
  def test_signin
    skip
    # post "/users/signin", username: "admin", password: "secret"
    post "/sign_in", user: "admin", pass: "secret"
    assert_equal 302, last_response.status
    assert_equal("Welcome!", session[:message])
    assert_equal("admin", session[:user])

    get last_response["Location"]
    assert_includes last_response.body, "Signed in as admin"
  end

  # Launch
  def test_signin_with_bad_credentials
    skip
    # post "/users/signin", username: "guest", password: "shhhh"
    post "/sign_in", user: "guest", pass: "shhhh"
    assert_equal 422, last_response.status
    assert_nil session[:user]
    assert_includes last_response.body, "Invalid Credentials"
  end

  # Launch
  def test_signout
    skip
    get "/", {}, {"rack.session" => { user: "admin", pass: "secret", signed_in: true } }
    assert_includes last_response.body, "Signed in as admin"

    # post "/users/signin", username: "admin", password: "secret"
    # post "/sign_in", user: "admin", pass: "secret"

    # get last_response["Location"]
    # assert_includes last_response.body, "Welcome"

    # post "/users/signout"
    post "/sign_out"
    assert_equal("You have been signed out", session[:message])

    get last_response["Location"]

    assert_nil(session[:user])
    assert_includes last_response.body, "Sign In"
  end

  def teardown
    FileUtils.rm_rf(data_path)
  end
end
