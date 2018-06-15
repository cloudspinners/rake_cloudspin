require_relative 'base_stack_tasks'

module RakeCloudspin
  module Tasks
    class Deployment < BaseStackTasks

      def stack_type
        'deployment'
      end

      def define_top_level_tasks
        desc 'Show the plan for changes to the deployment stacks'
        task :plan => stacks.map { |stack|
          :"deployment:#{stack}:plan"
        }

        desc 'Provision the deployment stacks'
        task :provision => stacks.map { |stack|
          :"deployment:#{stack}:provision"
        }

        unless stacks_with_tests.empty?
          desc 'Test the deployment stacks'
          task :test => stacks.map { |stack|
            :"deployment:#{stack}:test"
          }
        end

        desc 'Destroy the deployment stacks'
        task :destroy => stacks.map { |stack|
            :"deployment:#{stack}:destroy"
        }
      end

    end
  end
end

