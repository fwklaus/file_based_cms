# example test file
ENV["RACK_ENV"] = "test" # Sinatra uses this to determine whether or not to start a web server

require "minitest/autorun"
require "rack/test" # rack/test does not come built-in with Sinatra

require_relative "../app" # require main program relative to test file

class AppTest < Minitest::Test
  include Rack::Test::Methods # provides useful helper methods

  # the helper methods expect this method and an instance of a Rack application for a return value
  def app
    Sinatra::Application
  end

  def test_index
    get "/"
    assert_equal 200, last_response.status
    assert_equal "text/html;charset=utf-8", last_response["Content-Type"]
    assert_equal "Hello, world!", last_response.body
  end

  #def test_example
    # make a request to your app - use get, post, etc.
    # access the response - accessible using `last_response` 
        # returns an instance of Rack::MockResponse
            # can call status, body, [], on it
    # make standard Minitest assertions
  #end
end


