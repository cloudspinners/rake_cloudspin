module RakeCloudspin
  module Tasks
    class All < TaskLib

      parameter :deployment_stacks
      parameter :delivery_stacks
      parameter :configuration

      def define
        @configuration = Confidante.configuration(
          :hiera => Hiera.new(config: hiera_file)
        )
        @state_buckets = {}

        discover_deployment_stacks
        discover_delivery_stacks

        define_terraform_installation_tasks
        define_deployment_stacks_tasks
        define_delivery_stacks_tasks

        define_statebucket_tasks

        define_top_level_deployment_tasks
        define_top_level_delivery_tasks
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

      def define_stack_tasks(stack_type, stacks)
        namespace stack_type do
          stacks.each { |stack|
            namespace stack do
              StackTask.new do |t|
                t.stack_name = stack
                t.stack_type = stack_type
                t.configuration = configuration
              end
              if stack_needs_ssh_keys?(stack_type, stack)
                SshKeyTask.new do |t|
                  t.stack_name = stack
                  t.stack_type = stack_type
                  t.configuration = configuration
                end
              end
              StackTestTask.new do |t|
                t.stack_name = stack
                t.stack_type = stack_type
                t.configuration = configuration
              end
            end
            add_statebucket_if_required(stack_type, stack)
          }
        end
      end

      def define_top_level_deployment_tasks
        ['plan', 'provision', 'destroy', 'test'].each { |action|
          desc "#{action} for all deployment stacks"
          task action => @deployment_stacks.map { |stack|
            :"deployment:#{stack}:#{action}"
          }
        }
      end

      def define_top_level_delivery_tasks
        ['plan', 'provision', 'destroy', 'test'].each { |action|
          desc "#{action} for all delivery stacks"
          task "delivery_#{action}" => @delivery_stacks.map { |stack|
            :"delivery:#{stack}:#{action}"
          }
        }
      end

      def stack_needs_ssh_keys?(stack_type, stack)
        ! configuration
            .for_scope(stack_type => stack).ssh_keys.nil?
      end

      def stack_uses_s3_bucket?(stack_type, stack_name)
        state_config = configuration
            .for_scope(stack_type => stack_name).state
        ! state_config.nil? && state_config['type'] == 's3'
      end

      def add_statebucket_if_required(stack_type, stack_name)
        if stack_uses_s3_bucket?(stack_type, stack_name)
          state_configuration = configuration
              .for_scope(stack_type => stack_name).state
          state_scope = state_configuration['scope']
          if state_scope.nil?
            raise "Scope is not defined for remote state for stack_name '#{stack_name}'"
          elsif state_scope == 'deployment'
            add_deployment_statebucket_to_be_created(state_configuration)
          elsif state_scope == 'component'
            raise 'Component level statebucket not supported yet'
          elsif state_scope == 'account'
            raise 'Account level statebucket not supported yet'
          else
            raise "Unknown scope for statebucket: '#{state_scope}'"
          end
        end
      end

      def add_deployment_statebucket_to_be_created(stack_state_config)
        # TODO: This will overwrite it for each deployment. TBH I'm not sure
        # we need anything more than what the deployment_id is called; the
        # actual bucket configuration should be standard. But we may want
        # ability to override some settings.
        @state_buckets['deployment'] = stack_state_config
      end

      def define_statebucket_tasks
        @state_buckets.each { |scope, config|
          desc "Create statebucket for scope '#{scope}'"
          namespace scope do
            task :statebucket do
              puts "TODO: Create a statebucket: #{config.to_yaml}"
            end
          end
        }
      end

    end
  end
end
