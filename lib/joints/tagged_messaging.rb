Sequel::Plugins::ValidationHelpers::DEFAULT_OPTIONS.merge!(:presence => {:message => 'is required'})
Sequel::Model.plugin :timestamps, :create => :date_created, :update => :date_updated

Marley.joint 'basic_user'
Marley.joint 'tagging'
Marley.joint 'messaging',{:threaded => true,:resources => ['Message']}#:tagged => true,
module Marley
  module Joints
    class TaggedMessaging < Joint
      def smoke
        super
        t=Marley.plugin('tagging')
        t.apply('Message') 
        MR::PrivateMessage.tagging('User')
        MR::PublicMessage.tagging('User')
        MR::PublicMessage.tagging()
      end
      module Resources
        class PrivateMessage < MJ::Messaging::Resources::PrivateMessage
          attr_accessor :tags
          @actions_get= superclass.actions_get << 'new_tags'
          @section_title='Private Messages'
          @section_name='pms'
          def self.section_navigation
            $request[:user].user_tags.map{|t| [:link,{:url => "/private_message?private_message[tag]=#{t.tag}",:title => t.tag.humanize}]}.unshift(PrivateMessage.reggae_link('new'))
          end
          def rest_schema
            super << [:text, :tags, 0,tags]
          end
          def self.list(params={})
            super
            @items=@items.filter("author_id=#{$request[:user][:id]} or recipients like('%#{$request[:user][:name]}%')".lit)
            @items.group(:thread_id).order(:max.sql_function(:date_created).desc,:max.sql_function(:date_updated).desc).map{|t|self[:parent_id => nil, :thread_id => t[:thread_id]].thread} rescue []
          end
          def reply
            r=super
            r.tags=(user_tags_dataset.current_user_dataset.map{|t|t.tag} - RESERVED_PM_TAGS).join(',')
            r
          end
          def after_create
            add_user_tags("inbox,#{tags}",recipients)
            add_user_tags("sent,#{recipients.match(/\b#{author.name}\b/) ? '' : tags}",author_id)
          end
        end
        class PublicMessage < MJ::Messaging::Resources::PublicMessage
          attr_accessor :tags,:my_tags
          @section_title='Public Messages'
          @section_name='posts'
          def self.section_navigation
            MR::Tag.filter(:user_id => nil).map{|t| [:link,{:url => "/post?post[tag]=#{t.tag}",:title => t.tag.humanize}]}.unshift([:link,{:url => '/post?post[untagged]=true',:title => 'Untagged Messages'}]).unshift(PublicMessage.reggae_link('new'))
          end
          @actions_get=(superclass.actions_get << 'new_user_tags') << 'new_tags'
          def rest_schema
            (super << [:text, :tags, 0,tags] ) << [:text, :my_tags, 0,my_tags] 
          end
          def self.list(params={})
            super
            @items.group(:thread_id).order(:max.sql_function(:date_created).desc,:max.sql_function(:date_updated).desc).map{|t|self[:parent_id => nil, :thread_id => t[:thread_id]].thread} rescue []
          end
          def reply
            r=super
            r.tags=self.tags
            r
          end
          def after_create
            add_tags(tags) if tags
            add_user_tags(my_tags) if my_tags
          end
        end
      end
    end
  end
end
