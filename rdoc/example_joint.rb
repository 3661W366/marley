require 'rubygems'
require 'marley'

module Marley
  module Joints
    class ExampleJoint < Joint
      module HelloPlugin 
        module ClassMethods
          def rest_post
            new($request[:path][1])
          end
        end
        module InstanceMethods
          def initialize(greeting)
            @greeting=greeting
          end
          def to_json
            "#{@greeting} world"
          end
        end
      end
      module Resources
        class GoodBye
          def self.rest_get
            "goodbye"
          end
        end
      end
    end
  end
end
