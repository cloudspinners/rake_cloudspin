
module RakeCloudspin
  module Tasks
    class StackTask < BaseTask

      attr_reader :state_buckets

      def define
        RakeTerraform.define_command_tasks do |t|
          t.configuration_name = "#{stack_type}-#{stack_name}"
          t.source_directory = "#{stack_type}/#{stack_name}/infra"
          t.work_directory = 'work'

          puts "============================="
          puts "#{stack_type}/#{stack_name}"
          puts "============================="

          # TODO: Handle args that override configuration
          stack_state_configuration = stack_config.state

          if stack_state_configuration.nil? || stack_state_configuration['type'].to_s.empty? || stack_state_configuration['type'] == 'local'
            t.state_file = local_state_configuration
          elsif stack_state_configuration['type'] == 's3'
            t.backend_config = remote_state_configuration
          else
            raise "ERROR: Unknown stack state type '#{stack_state_configuration['type']}' for #{stack_type} stack '#{stack_name}'"
          end

          t.vars = lambda do |args|
            puts "Terraform variables:"
            puts "---------------------------------------"
            puts "#{configuration['vars'].to_yaml}"
            puts "---------------------------------------"
            configuration['vars']
          end
        end
      end

      def local_state_configuration
        lambda do |args|
          local_statefile_path(args)
        end
      end

      def local_statefile_path(args)
        Paths.from_project_root_directory(
            'state',
            stack_config('deployment_identifier') || 'component',
            stack_config('component'),
            stack_type,
            "#{stack_name}.tfstate")
      end

      def remote_state_configuration
        backend_config = lambda do |args|
          stack_config(args).state
        end
        puts "Terraform backend configuration:"
        puts "---------------------------------------"
        puts "#{backend_config.call({}).to_yaml}"
        puts "---------------------------------------"
        backend_config
      end

    end
  end
end
