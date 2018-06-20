
module RakeCloudspin
  module Tasks
    class StackTask < BaseTask

      # parameter :state_type, :required => true
      # parameter :remote_state_configuration

      def define
        define_terraform_tasks
        define_vars_task
      end

      def define_terraform_tasks
        RakeTerraform.define_command_tasks do |t|
          t.configuration_name = "#{stack_type}-#{stack_name}"
          t.source_directory = "#{stack_type}/#{stack_name}/infra"
          t.work_directory = 'work'
          t.vars = terraform_vars_builder
          if uses_local_state?
            t.state_file = local_state_path_builder
          elsif uses_remote_state?
            t.backend_config = backend_config_builder
          else
            raise "ERROR: state_type '#{state_type}' not supported"
          end
        end
      end

      def define_vars_task
        desc "Show terraform variables for stack '#{stack_name}'"
        task :vars do |t, args|
          puts "Terraform variables for stack '#{stack_name}'"
          puts "---------------------------------------"
          puts "#{terraform_vars_builder.call(args).to_yaml}"
          puts "---------------------------------------"
          if uses_local_state?
            puts "Local statefile path:"
            puts "---------------------------------------"
            puts "#{local_state_path_builder.call(args)}"
          elsif uses_remote_state?
            puts "Backend configuration for stack '#{stack_name}':"
            puts "---------------------------------------"
            puts "#{backend_config_builder.call(args).to_yaml}"
          else
            puts "Unknown state configuration type ('#{state_type}')"
          end
          puts "---------------------------------------"
        end
      end

      # def assign_state_configuration(task)
      #     # TODO: Handle args that override configuration
      #     if uses_local_state?
      #       task.state_file = local_state_configuration
      #     elsif uses_remote_state?
      #       task.backend_config = remote_statebucket.config
      #     else
      #       raise "ERROR: Unknown stack state type '#{state_configuration['type']}' for #{stack_type} stack '#{stack_name}'"
      #     end
      # end

      def uses_local_state?
        state_configuration.nil? ||
          state_configuration['type'].to_s.empty? || 
          state_configuration['type'] == 'local'
      end

      def uses_remote_state?
        ! state_configuration.nil? &&
          ! state_configuration['type'].to_s.empty? &&
          state_configuration['type'] == 's3'
      end

      def state_configuration
        stack_config.state
      end

      # def remote_statebucket
      #   if @remote_statebucket.nil?
      #     scope = state_configuration['scope']
      #     if scope == 'deployment'

      #     end
      #   end
      # end

      def terraform_vars_builder
        lambda do |args|
          stack_config.vars
        end
      end

      def local_state_path_builder
        lambda do |args|
          Paths.from_project_root_directory(
              'state',
              stack_config(args).deployment_identifier || 'delivery',
              stack_config(args).component,
              stack_type,
              "#{stack_name}.tfstate")
          end
      end

      def backend_config_builder
        lambda do |args|
          {
            'region' => stack_config.region,
            'bucket' => Statebucket.build_bucket_name(
              estate: stack_config(args).estate, 
              deployment_identifier: stack_config(args).deployment_identifier,
              component: stack_config(args).component
            ),
            'key' => state_key(args),
            'encrypt' => true
          }
        end
      end

      def state_key(args)
        [
          stack_config(args).deployment_identifier || 'delivery',
          stack_config(args).component,
          stack_type,
          "#{stack_name}.tfstate"
        ].join('/')
      end

      # def remote_state_configuration
      #   bucket = 
      #   lambda do |args|
      #     {
      #       'region' => stack_config('region')
      #       'bucket' => 
      #       'key' => remote_state_path,
      #       'encrypt' => "%{hiera('deployment_statebucket_is_encrypted')}"
      #     }
      #   end
      # end

      # def remote_state_path
      #   "state-%{stack_config('estate')}-state-%{stack_config('component')}-state-%{stack_config('deployment_identifier')}- %{hiera('component')}-deployment-%{hiera('environment_identifier')}"
      # end

    end
  end
end
