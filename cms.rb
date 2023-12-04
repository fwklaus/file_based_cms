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

before do
  # session[:signed_in] ||= false
  session[:user] ||= nil
end

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
end

# returns appropriate path for current environment
def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def data_path_credentials
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/test", __FILE__)
  else
    File.expand_path("../test", __FILE__)
  end
end

# Load User Credentials
def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/test/users.yml", __FILE__)
  else
    File.expand_path("../test/users.yml", __FILE__)
  end
  Psych.load_file(credentials_path)
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

def password_already_in_use?(file, password)
  file.each do |username, pass|
    return true if check?(password, pass)
  end
end

def username_and_pass_unique?(file, username, password)
  return false if file.nil?
  return true if file.has_key?(username) || 
                  password_already_in_use?(file, password)
  false
end

def encrypt(password)
  BCrypt::Password.create(password)
end

def write_users_file(file)
  path = File.join(data_path_credentials, "users.yml")
  File.write(path, file)
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
  unless session[:user]
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

get "/sign_up" do
  erb :sign_up
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
  unless session[:user]
    session[:message] = "You must be signed in to do that."
    redirect "/"
  else
    file_path = File.join(data_path, params[:file])
    @file = params[:file]
    @contents = File.read(file_path)

    erb :edit_file
  end
end

post "/sign_up" do
  username = params[:user]
  password = params[:pass]
  file = load_user_credentials
  file = {} if file.nil?

  unless username_and_pass_unique?(file, username, password)
    session[:message] = "Username or password already exists"
    erb :sign_up
  else
    encrypted_pass = encrypt(password)
    file[username] = encrypted_pass
    write_users_file(file)
    session[:message] = "Welcome new user!"
    redirect "/"
  end
end

# create a new file
post "/new" do
  unless session[:user]
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
  unless session[:user]
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

# sign in
post "/sign_in" do
  user, pass = params[:user], params[:pass]

  unless valid_credentials?(user, pass)
    session[:message] = "Invalid Credentials"
    status(422)
    erb :sign_in, layout: :layout
  else 
    session[:user] = user
    session[:message] = "Welcome!"
    redirect "/"
  end
end

# sign out
post "/sign_out" do
  session[:user] = nil
  session[:message] = "You have been signed out"
  redirect "/"
end

# delete a file
post "/:file/delete" do
  unless session[:user]
    session[:message] = "You must be signed in to do that."
    redirect "/"
  else
    file = params[:file]
    FileUtils.rm(File.join(data_path, file))
    session[:message] = "#{file} was deleted"
    redirect "/"
  end
end
