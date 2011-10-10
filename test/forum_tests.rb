require 'rubygems'
require 'test/unit'
require 'shoulda'
EXAMPLES_DIR=File.dirname(__FILE__) + '/../examples'

`cp #{EXAMPLES_DIR}/empty.sqlite3 #{EXAMPLES_DIR}/forum_test.sqlite3`
ARGV[0]='test'
require "#{EXAMPLES_DIR}/forum.rb"
require "#{EXAMPLES_DIR}/../lib/test_helpers"

class BasicTests < Test::Unit::TestCase
  context "no user" do
    setup do
      Marley::Resources::User.delete
      @client=Marley::TestClient.new(:resource_name => 'user',:code => 400)
    end
    should "return login form with no params" do
      assert @client.read({},{:resource_name => '',:code => 200})
    end
    should "return an error when trying to create a user with no params" do
      assert resp=@client.create
      assert_equal "validation", resp.resource_type
      assert_equal ["is required"], resp.properties['name']
    end
    should "return an error when trying to create a user with only a name" do
      resp=@client.create({:'user[name]' => 'asdf'})
      assert_equal "validation", resp.resource_type
    end
    should "return an error when password is too short" do
      resp=@client.create({:'user[name]' => 'asdf',:'user[password]' => 'asdfaf'})
      assert_equal "validation", resp.resource_type
      assert_equal ["Password must contain at least 8 characters"], resp.properties['password']
    end
    should "return an error when trying to create a user with only a name and password" do
      resp=@client.create(:'user[name]' => 'asdf',:'user[password]' => 'asdfasdf')
      assert_equal "validation", resp.resource_type
      assert_equal ["Passwords do not match"], resp.properties['confirm_password']
    end
    should "allow creation of a new user and disallow user with the same name" do
      @client.code=200
      @client.create(:'user[name]' => 'asdf',:'user[password]' => 'asdfasdf',:'user[confirm_password]' => 'asdfasdf')
      @client.create(:'user[name]' => 'asdf',:'user[password]' => 'asdfasdf',:'user[confirm_password]' => 'asdfasdf')
    end
    should "not allow access to menus" do
      @client.read({:resource_name =>'pm_menu'},{:code => 401})
      @client.read({:resource_name =>'post_menu'},{:code => 401})
    end
  end
  context "menus for logged in users" do
    setup do
      Marley::Resources::User.delete
      @client=Marley::TestClient.new(:resource_name => 'user')
      @client.create(:'user[name]' => 'asdf',:'user[password]' => 'asdfasdf',:'user[confirm_password]' => 'asdfasdf')
      @client.auth=['asdf','asdfasdf']
    end
    should "show main menu, PM menu and Posts menu" do
      assert @client.read({},:resource_name => '')
      assert @client.read({},:resource_name => 'pm_menu')
      assert @client.read({},:resource_name => 'post_menu')
    end
  end
end
class MessageTests < Test::Unit::TestCase
  context "Private Messages" do
    setup do
      Marley::Resources::User.delete
      Marley::Resources::Message.delete
      Marley::Resources::Tag.delete
      DB[:messages_tags].delete
      @client=Marley::TestClient.new(:resource_name => 'user')
      @client.create(:'user[name]' => 'user1',:'user[password]' => 'asdfasdf',:'user[confirm_password]' => 'asdfasdf')
      @client.create(:'user[name]' => 'user2',:'user[password]' => 'asdfasdf',:'user[confirm_password]' => 'asdfasdf')
      @client.create(:'user[name]' => 'admin',:'user[password]' => 'asdfasdf',:'user[confirm_password]' => 'asdfasdf')
      @admin_auth=['admin','asdfasdf']
      @user1_auth=['user1','asdfasdf']
      @user2_auth=['user2','asdfasdf']
      Marley::Resources::User[:name => 'admin'].update(:user_type => 'Admin')
      @client.resource_name='private_message'
    end
    context "regular user validations" do
      setup do
        @client.auth=@user1_auth
      end
      should "show PM list" do
        assert @client.read({})
      end
      should "reject a PM with only recipients" do
        resp=@client.create({:'private_message[recipients]' => 'user2'},{:code => 400})
        assert_equal "validation", resp.resource_type
        assert_equal ["is required"], resp.properties['title']
        assert_equal ["is required"], resp.properties['message']
      end
      should "reject a PM to a non-existent user" do
        resp=@client.create({:'private_message[recipients]' => 'asdfasdfasdfasdf',:'private_message[title]' => 'asdf',:'private_message[message]' => 'asdf'},{:code => 400})
        assert_equal "validation", resp.resource_type
        assert resp.properties['recipients']
      end
      should "reject a PM from user to user" do
        resp=@client.create({:'private_message[recipients]' => 'user2',:'private_message[title]' => 'asdf',:'private_message[message]' => 'asdf'},{:code => 400})
        assert_equal "validation", resp.resource_type
        assert resp.properties['recipients']
      end
      should "accept a PM to admin" do
         assert @client.create({:'private_message[recipients]' => 'admin',:'private_message[title]' => 'asdf',:'private_message[message]' => 'asdf'})
      end
    end
    context "admin validations" do
      setup do
        @client.auth=@admin_auth
      end
      should "reject a PM with only recipients" do
        resp=@client.create({:'private_message[recipients]' => 'user2'},{:code => 400})
        assert_equal "validation", resp.resource_type
        assert_equal ["is required"], resp.properties['title']
        assert_equal ["is required"], resp.properties['message']
      end
      should "accept a PM to user1" do
         assert @client.create({:'private_message[recipients]' => 'user1',:'private_message[title]' => 'asdf',:'private_message[message]' => 'asdf'})
      end
    end
    context "message with no tags" do
      setup do
        @client.auth=@admin_auth
        @client.create({:'private_message[recipients]' => 'user1',:'private_message[title]' => 'asdf',:'private_message[message]' => 'asdf'})
      end
      should "show up in PM list of sender and receiver" do
        resp=@client.read({})
        assert_equal 1, resp.length
        resp=@client.read({},{:auth => @user1_auth})
        assert_equal 1, resp.length
      end
      should "have sent tag for sender" do
        resp=@client.read({})
        assert_equal 3, resp[0].length
        assert_equal "sent", resp.find_instances('user_tag')[0].schema[:tag].col_value
      end
      should "have inbox tag for receiver" do
        resp=@client.read({},{:auth => @user1_auth})
        assert_equal 3, resp[0].length
        assert_equal "inbox", resp.find_instances('user_tag')[0].schema[:tag].col_value
      end
      should "have reply, reply_all and new_tags instance get actions" do
        resp=@client.read({})
        assert_same_elements ['reply','reply_all','new_tags'], resp[0].instance_get_actions
      end
      context "user1 instance actions" do
        setup do
          @client.auth=@user1_auth
          @msg=@client.read({})[0].to_resource
          @client.instance_id=@msg.schema[:id].col_value
          @reply=@client.read({},{:method => 'reply'}).to_resource
          @new_tags=@client.read({},:method => 'new_tags').to_resource
        end
        context "reply" do
          should "have author in to field and default title beginning with 're:'" do
            assert_equal 'admin', @reply.schema[:recipients].col_value
            assert_equal 're: ', @reply.schema[:title].col_value[0 .. 3]
          end
          should "accept reply" do
            assert @client.create(@reply.to_params.merge('private_message[message]' => 'asdf'),{:method => nil,:instance_id => nil})
          end
        end
        context "new tags" do
          should "return tag instance with name tag and same url as original message" do
            assert_equal 'tags', @new_tags.name
            assert_equal "#{@msg.url}tags", @new_tags.url
          end
          should "accept new tags, which should then show up with the original message" do
            assert @client.create({'private_message[tags]' => 'added_tag1, added_tag2'},{:method => 'tags'})
            msg=@client.read({})
            user_tags=msg.find_instances('user_tag')
            assert_same_elements ["inbox", "added_tag1", "added_tag2"], user_tags.map{|t| t.schema[:tag].col_value}
          end
        end
      end
    end
    context "message with 2 tags" do
      setup do
        @client.auth=@admin_auth
        @client.create({:'private_message[recipients]' => 'user1',:'private_message[title]' => 'asdf',:'private_message[message]' => 'asdf', :'private_message[tags]' => 'test,test2'})
      end
      should "have sent tag and both specified tags for sender" do
        resp=@client.read({})
        user_tags=resp[0].find_instances('user_tag')
        assert_same_elements ["sent", "test", "test2"], user_tags.map{|t| t.schema[:tag].col_value}
      end
      context "receiver (user1)" do
        setup do
          @client.auth=@user1_auth
          @resp=@client.read
        end
        should "have inbox tag and both specified tags" do
          user_tags=@resp[0].find_instances('user_tag')
          assert_same_elements ["inbox", "test", "test2"], user_tags.map{|t| t.schema[:tag].col_value}
        end
        should "have specified tags in reply" do
          reply=@client.read({},{:instance_id => @resp[0].schema[:id].col_value,:method => 'reply'}).to_resource
          assert_equal 'test,test2', reply.schema[:tags].col_value
        end
      end
      context 'user2' do
        should "have no messages" do
          assert resp=@client.read({},{:auth => @user2_auth})
          assert_equal 0, resp.length
        end
      end
    end
    context "message with 2 tags and 2 receivers" do
      setup do
        @client.create({:'private_message[recipients]' => 'user1,user2',:'private_message[title]' => 'asdf',:'private_message[message]' => 'asdf', :'private_message[tags]' => 'test,test2'},{:auth => @admin_auth})
      end
      should "have sent tag and both specified for sender" do
        resp=@client.read({},{:auth => @admin_auth})
        user_tags=resp[0].find_instances('user_tag')
        assert_same_elements ["sent", "test", "test2"], user_tags.map{|t| t.schema[:tag].col_value}
      end
      should "have inbox tag and both specified for 1st receiver (user1)" do
        resp=@client.read({},{:auth => @user1_auth})
        user_tags=resp[0].find_instances('user_tag')
        assert_same_elements ["inbox", "test", "test2"], user_tags.map{|t| t.schema[:tag].col_value}
      end
      should "have inbox tag and both specified for 2st receiver (user2)" do
        resp=@client.read({},{:auth => @user2_auth})
        user_tags=resp[0].find_instances('user_tag')
        assert_same_elements ["inbox", "test", "test2"], user_tags.map{|t| t.schema[:tag].col_value}
      end
    end
    context "message listing" do
      setup do
        #3 messages with tag "test" for user 1
        @client.create({:'private_message[recipients]' => 'user1',:'private_message[title]' => 'title1',:'private_message[message]' => 'body1', :'private_message[tags]' => 'test'},{:auth => @admin_auth})
        @client.create({:'private_message[recipients]' => 'user1',:'private_message[title]' => 'title2',:'private_message[message]' => 'body2', :'private_message[tags]' => 'test'},{:auth => @admin_auth})
        @client.create({:'private_message[recipients]' => 'user1',:'private_message[title]' => 'title3',:'private_message[message]' => 'body3', :'private_message[tags]' => 'test'},{:auth => @admin_auth})
        #2 messages with tag "test1" for user1 and user2
        @client.create({:'private_message[recipients]' => 'user2,user1',:'private_message[title]' => 'title1',:'private_message[message]' => 'body1', :'private_message[tags]' => 'test1'},{:auth => @admin_auth})
        @client.create({:'private_message[recipients]' => 'user2,user1',:'private_message[title]' => 'title2',:'private_message[message]' => 'body2', :'private_message[tags]' => 'test1'},{:auth => @admin_auth})
      end
      context "sender (admin) listings" do
        setup do
          @client.auth=@admin_auth
        end
        should "show 3 messages with 'test' tag" do
          assert_equal 3, @client.read({:'private_message[tags]' => 'test'}).length
        end
        should "show 2 messages with 'test1' tag" do
          assert_equal 2, @client.read({:'private_message[tags]' => 'test1'}).length
        end
        should "show 5 messages with 'sent' tag" do
          assert_equal 5, @client.read({:'private_message[tags]' => 'sent'}).length
        end
      end
      context "user1 listings" do
        setup do
          @client.auth=@user1_auth
        end
        should "show 3 messages with 'test' tag" do
          assert_equal 3, @client.read({:'private_message[tags]' => 'test'}).length
        end
        should "show 2 messages with 'test1' tag" do
          assert_equal 2, @client.read({:'private_message[tags]' => 'test1'}).length
        end
        should "show 5 messages with 'inbox' tag" do
          assert_equal 5, @client.read({:'private_message[tags]' => 'inbox'}).length
        end
        should "show 5 messages with 'test' or 'test1' tags" do
          assert_equal 5, @client.read({:'private_message[tags]' => 'test,test1'}).length
        end
      end
      context "user2 listings" do
        setup do
          @client.auth=@user2_auth
        end
        should "show 0 messages with 'test' tag" do
          assert_equal 0, @client.read({:'private_message[tags]' => 'test'}).length
        end
        should "show 2 messages with 'test1' tag" do
          assert_equal 2, @client.read({:'private_message[tags]' => 'test1'}).length
        end
        should "show 2 messages with 'inbox' tag" do
          assert_equal 2, @client.read({:'private_message[tags]' => 'inbox'}).length
        end
        should "show 2 messages with 'test' or 'test1' tags" do
          assert_equal 2, @client.read({:'private_message[tags]' => 'test,test1'}).length
        end
      end
    end
  end
end
