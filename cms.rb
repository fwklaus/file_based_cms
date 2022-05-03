require "sinatra"
require "sinatra/content_for"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "pry"
require "psych"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, 'secret' 
end

# -before filter

helpers do
  # render markdown file as HTML and render it
  def render_markdown(file)
    file_contents = File.read(File.join(data_path, file))
    markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
    markdown.render(file_contents)
  end

  # displays error message if file does not exits
  # also displays whether file has been updated
  def display_message
    if session[:message]
      session.delete(:message)
    end
  end

  # sets id value for <p> if there's a message for rendering in layout.erb
  def display_if_message
    if session[:message]
      "message"
    end
  end

  # check if the user is logged in
  def logged_in?
    session[:signed_in]  
  end
end

# returns appropriate path for current environment
def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

# load credentials based on the current environment
def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

# verify that a user has access
def valid_credentials?(user, pass)
  users = load_user_credentials

  users.key?(user) &&
  users.any? { |usr, ncrptd_pss| usr == user && check?(pass, ncrptd_pss) }
end

# verify that a given raw password is equal to a hashed password
def check?(password, encrypted_password)
  BCrypt::Password.new(encrypted_password) == password
end

# home page
get "/" do
  pattern = File.join(data_path, "*")
  @files = Dir.glob(pattern).map do |path|
    File.basename(path)
  end

  erb :index
end

# new document page
get "/new" do
  unless logged_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  else
    erb :new
  end
end

# renders sign_in form
get "/sign_in" do
  erb :sign_in
end

# displays file contents, or error message if file does not exist
get "/:file" do
  file_path = File.join(data_path, params[:file])
  file_name = params[:file]

  pattern = File.join(data_path, "*")
  files = Dir.glob(pattern).map { |file| File.basename(file)}
  
  if File.extname(file_path) == ".md"
    render_markdown(file_name)
  elsif files.include?(file_name)
    headers["Content-Type"] = "text/plain"
    File.read(File.join(data_path, file_name))
  else
    base_name = File.basename(file_name)
    session[:message] = "#{file_name} does not exist."
    redirect "/"
  end
end

# render page to edit file's contents
get "/:file/edit" do
  unless logged_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  else
    file_path = File.join(data_path, params[:file])
    @file = params[:file]
    @contents = File.read(file_path)

    erb :edit_file
  end
end

# create a new file
post "/new" do
  unless logged_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  else
    new_file = params[:new_file]

    if new_file.size <= 0 
      session[:message] = "A name is required"
      status 422
      erb :new
    elsif File.extname(new_file).empty?
      session[:message] = "Need file extension for valid file"
      erb :new
    else
      session[:message] = "#{new_file} was created"
      FileUtils.touch(File.join(data_path, new_file))
      redirect "/"
    end
  end
end

# edit the contents of a file and redirect to index page
post "/:file/edit" do
  unless logged_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  else
    file_path = File.join(data_path, params[:file])
    file = params[:file]
    
    File.write(file_path, params[:content])
  
    session[:message] = "#{file} has been updated."
    redirect "/"
  end
end

# delete a file
post "/:file/delete" do
  unless logged_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  else
    file = params[:file]
    FileUtils.rm(File.join(data_path, file))
    session[:message] = "#{file} was deleted"
    redirect "/"
  end
end

# sign in
post "/sign_in" do
  user, pass = params[:user], params[:pass]

  unless valid_credentials?(user, pass)
    session[:message] = "Invalid Credentials"
    status(422)
    erb :sign_in, layout: :layout
  else 
    session[:signed_in] = true
    session[:user] = user
    session[:message] = "Welcome!"
    redirect "/"
  end
end

# sign out
post "/sign_out" do
  session[:signed_in] = false
  session.delete(:user)
  session[:message] = "You have been signed out"
  redirect "/"
end


# Something is broken with the sign_in and the valid_credentials?