require_relative 'base_stack_tasks'

module RakeCloudspin
  module Tasks
    class DeliveryStackTasks < BaseStackTasks

      def stack_type
        'delivery'
      end

      def define_top_level_tasks
        desc 'Show the plan for changes to the delivery stacks'
        task :delivery_plan => stacks.map { |stack|
          :"delivery:#{stack}:plan"
        }

        desc 'Provision the delivery stacks'
        task :delivery_provision => stacks.map { |stack|
          :"delivery:#{stack}:provision"
        }

        unless stacks_with_tests.empty?
          desc 'Test the delivery stacks'
          task :delivery_test => stacks_with_tests.map { |stack|
            :"delivery:#{stack}:test"
          }
        end

        desc 'Destroy the delivery stacks'
        task :delivery_destroy => stacks.map { |stack|
          :"delivery:#{stack}:destroy"
        }
      end

    end
  end
end

