require 'rubygems'
require 'test/unit'
require "rack/test"
require 'shoulda'
EXAMPLES_DIR=File.dirname(__FILE__) + '/../examples'

`cp #{EXAMPLES_DIR}/empty.sqlite3 #{EXAMPLES_DIR}/forum_test.sqlite3`
ARGV[0]='test'
require "#{EXAMPLES_DIR}/forum.rb"
require "#{EXAMPLES_DIR}/../lib/test_helpers"

class ForumTests < Test::Unit::TestCase
  include Rack::Test::Methods
  include Marley::TestHelpers
  def app
    Marley::Router.new
  end

  context "no user" do
    setup do
      Marley::Resources::User.delete
      @marley_test={:root_uri => '', :resource => 'user'}
    end
    should "return login form with no params" do
      get '/'
      assert_equal 200, last_response.status
    end
    should "return an error when trying to create a user with no params" do
      resp=marley_create(:code => 400 )
      assert_equal "validation", resp[0]
      assert_equal ["is required"], resp[1]['name']
    end
    should "return an error when trying to create a user with only a name" do
      resp=marley_create(:code => 400, :'user[name]' => 'asdf')
      assert_equal "validation", resp[0]
    end
    should "return an error when password is too short" do
      resp=marley_create(:code => 400, :'user[name]' => 'asdf',:'user[password]' => 'asdfaf')
      assert_equal "validation", resp[0]
      assert_equal ["Password must contain at least 8 characters"], resp[1]['password']
    end
    should "return an error when trying to create a user with only a name and password" do
      resp=marley_create(:code => 400, :'user[name]' => 'asdf',:'user[password]' => 'asdfasdf')
      assert_equal "validation", resp[0]
      assert_equal ["Passwords do not match"], resp[1]['confirm_password']
    end
    should "allow creation of a new user and disallow user with the same name" do
      marley_create(:'user[name]' => 'asdf',:'user[password]' => 'asdfasdf',:'user[confirm_password]' => 'asdfasdf')
      marley_create(:code => 400,:'user[name]' => 'asdf',:'user[password]' => 'asdfasdf',:'user[confirm_password]' => 'asdfasdf')
    end
    should "not allow access to menus" do
      @marley_test[:resource]='pm_menu'
      marley_read({:code => 401})
      @marley_test[:resource]='post_menu'
      marley_read({:code => 401})
    end
  end
  context "menus for logged in users" do
    setup do
      Marley::Resources::User.delete
      @marley_test={:root_uri => '', :resource => 'user'}
      marley_create(:'user[name]' => 'asdf',:'user[password]' => 'asdfasdf',:'user[confirm_password]' => 'asdfasdf')
      @marley_test={:root_uri => '', :resource => ''}
      authorize 'asdf','asdfasdf'
    end
    should "show main menu" do
      marley_read({})
    end
    should "show PM menu" do
      @marley_test[:resource]='pm_menu'
      marley_read({})
    end
    should "show Posts menu" do
      @marley_test[:resource]='post_menu'
      marley_read({})
    end
  end

  context "PM validation" do
    setup do
      Marley::Resources::User.delete
      Marley::Resources::Message.delete
      Marley::Resources::Tag.delete
      @marley_test={:root_uri => '', :resource => 'user'}
      marley_create(:'user[name]' => 'user1',:'user[password]' => 'asdfasdf',:'user[confirm_password]' => 'asdfasdf')
      marley_create(:'user[name]' => 'user2',:'user[password]' => 'asdfasdf',:'user[confirm_password]' => 'asdfasdf')
      marley_create(:'user[name]' => 'admin',:'user[password]' => 'asdfasdf',:'user[confirm_password]' => 'asdfasdf')
      Marley::Resources::User[:name => 'admin'].update(:user_type => 'Admin')
      @marley_test[:resource]='private_message'
    end
    should "work" do
      true
    end
  end
end

class MessageTests < Test::Unit::TestCase
  include Rack::Test::Methods
  include Marley::TestHelpers
  def setup
    Marley::Resources::User.delete
    Marley::Resources::Message.delete
    Marley::Resources::Tag.delete
    @marley_test={:root_uri => '', :resource => 'user'}
    marley_create(:'user[name]' => 'user1',:'user[password]' => 'asdfasdf',:'user[confirm_password]' => 'asdfasdf')
    marley_create(:'user[name]' => 'user2',:'user[password]' => 'asdfasdf',:'user[confirm_password]' => 'asdfasdf')
    marley_create(:'user[name]' => 'user3',:'user[password]' => 'asdfasdf',:'user[confirm_password]' => 'asdfasdf')
    marley_create(:'user[name]' => 'user4',:'user[password]' => 'asdfasdf',:'user[confirm_password]' => 'asdfasdf')
    marley_create(:'user[name]' => 'user5',:'user[password]' => 'asdfasdf',:'user[confirm_password]' => 'asdfasdf')
  end
  def app
    Marley::Router.new
  end
  def test_private_message
    @marley_test={:root_uri => '', :resource => 'private_message'}
    authorize 'user1','asdfasdf'
    marley_read({})
    marley_create({:code => 400,:'private_message[recipients]' => 'user2'})
    Marley::Resources::User[:name => 'user1'].update(:user_type => 'Admin')
    marley_create({:code => 400,:'private_message[recipients]' => 'user2',:'private_message[message]' => 'asdf'})
    marley_create({:'private_message[recipients]' => 'user2',:'private_message[title]' => 'asdf',:'private_message[message]' => 'asdf'})
  end
  def test_posts
    @marley_test={:root_uri => '', :resource => 'post'}
    marley_read({:code => 401})
    authorize 'user1','asdfasdf'
    marley_read({})
  end

end
