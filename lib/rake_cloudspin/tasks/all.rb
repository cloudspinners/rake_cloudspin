module RakeCloudspin
  module Tasks
    class All < TaskLib

      parameter :deployment_stacks
      parameter :delivery_stacks
      parameter :account_stacks
      parameter :configuration

      def define
        @configuration = Confidante.configuration(
          :hiera => Hiera.new(config: hiera_file)
        )
        @deployment_statebucket_required = false

        discover_deployment_stacks
        discover_delivery_stacks
        discover_account_stacks

        define_terraform_installation_tasks
        define_deployment_stacks_tasks
        define_delivery_stacks_tasks
        define_account_stacks_tasks

        define_statebucket_tasks

        define_top_level_deployment_tasks
        define_top_level_delivery_tasks
        define_top_level_account_tasks
      end

      def hiera_file
        File.expand_path(File.join(File.dirname(__FILE__), 'hiera.yaml'))
      end

      def discover_deployment_stacks
        @deployment_stacks = discover_stacks('deployment')
      end

      def discover_delivery_stacks
        @delivery_stacks = discover_stacks('delivery')
      end

      def discover_account_stacks
        @account_stacks = discover_stacks('account')
      end

      def discover_stacks(stack_type)
        if Dir.exist?(stack_type)
          Dir.entries(stack_type).select { |stack|
            File.directory? File.join(stack_type, stack) and File.exists?("#{stack_type}/#{stack}/stack.yaml")
          }
        else
          []
        end
      end

      def define_terraform_installation_tasks
        RakeTerraform.define_installation_tasks(
          path: File.join(Dir.pwd, 'vendor', 'terraform'),
          version: '0.11.7'
        )
      end

      def define_deployment_stacks_tasks
        define_stack_tasks('deployment', @deployment_stacks)
      end

      def define_delivery_stacks_tasks
        define_stack_tasks('delivery', @delivery_stacks)
      end

      def define_account_stacks_tasks
        define_stack_tasks('account', @account_stacks)
      end

      def define_stack_tasks(stack_type, stacks)
        namespace stack_type do
          stacks.each { |stack_name|
            namespace stack_name do
              StackTask.new do |t|
                t.stack_name = stack_name
                t.stack_type = stack_type
                t.configuration = configuration
              end
              if deployment_statebucket_required?(stack_type, stack_name)
                @deployment_statebucket_required = true
              end
              if stack_needs_ssh_keys?(stack_type, stack_name)
                SshKeyTask.new do |t|
                  t.stack_name = stack_name
                  t.stack_type = stack_type
                  t.configuration = configuration
                end
              end
              StackTestTask.new do |t|
                t.stack_name = stack_name
                t.stack_type = stack_type
                t.configuration = configuration
              end
            end
          }
        end
      end

      def define_statebucket_tasks
        if @deployment_statebucket_required

          namespace 'deployment' do

            namespace 'statebucket' do
              DeploymentStatebucketTask.new do |t|
                t.configuration = configuration
              end
            end

            @deployment_stacks.each {|stack_name|
              task "#{stack_name}:plan" => [ 'statebucket:plan' ]
              task "#{stack_name}:provision" => [ 'statebucket:provision' ]
              task "#{stack_name}:vars" => [ 'statebucket:vars' ]
            }

          end
        end
      end

      def define_top_level_deployment_tasks
        ['plan', 'provision', 'destroy', 'test', 'vars'].each { |action|
          desc "#{action} for all deployment stacks"
          task action => @deployment_stacks.map { |stack|
            :"deployment:#{stack}:#{action}"
          }
        }
      end

      def define_top_level_delivery_tasks
        ['plan', 'provision', 'destroy', 'test', 'vars'].each { |action|
          desc "#{action} for all delivery stacks"
          task "delivery_#{action}" => @delivery_stacks.map { |stack|
            :"delivery:#{stack}:#{action}"
          }
        }
      end

      def define_top_level_account_tasks
        ['plan', 'provision', 'destroy', 'test', 'vars'].each { |action|
          desc "#{action} for all account stacks"
          task "delivery_#{action}" => @delivery_stacks.map { |stack|
            :"account:#{stack}:#{action}"
          }
        }
      end

      def stack_needs_ssh_keys?(stack_type, stack)
        ! configuration
            .for_scope(stack_type => stack).ssh_keys.nil?
      end

      def stack_uses_remote_state?(stack_type, stack_name)
        state_config = configuration
            .for_scope(stack_type => stack_name).state
        ! state_config.nil? && state_config['type'] == 's3'
      end

      def deployment_statebucket_required?(stack_type, stack_name)
        state_config = configuration
            .for_scope(stack_type => stack_name).state

        ! state_config.nil? && 
            state_config['type'] == 's3' &&
            state_config['scope'] == 'deployment'
      end

    end
  end
end
