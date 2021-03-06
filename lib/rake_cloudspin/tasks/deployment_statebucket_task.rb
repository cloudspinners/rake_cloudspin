
module RakeCloudspin
  module Tasks
    class DeploymentStatebucketTask < TaskLib

      parameter :configuration, :required => true

      def define
        define_terraform_tasks
        define_vars_task
      end

      def define_terraform_tasks
        RakeTerraform.define_command_tasks do |t|
          t.configuration_name = "deployment-statebucket"
          t.source_directory = source_directory
          t.work_directory = 'work'
          t.vars = terraform_vars_builder
          t.state_file = local_state_path_builder
        end
      end

      def source_directory
        File.expand_path(File.join(File.dirname(__FILE__), '..', '..', 'statebucket', 'infra'))
      end

      def define_vars_task
        desc "Show terraform variables for deployment statebucket'"
        task :vars do |t, args|
          puts "Terraform variables for statebucket"
          puts "---------------------------------------"
          puts "#{terraform_vars_builder.call(args).to_yaml}"
          puts "---------------------------------------"
          puts "Local statefile path:"
          puts "---------------------------------------"
          puts "#{local_state_path_builder.call(args)}"
          puts "---------------------------------------"
        end
      end

      def terraform_vars_builder
        lambda do |args|
          {
            'region' => configuration.region,
            'state_bucket_name' => Statebucket.build_bucket_name(
                estate: config(args).estate, 
                deployment_identifier: config(args).deployment_identifier,
                component: config(args).component
            ),
            'component' => config(args).component,
            'estate' => config(args).estate,
            'deployment_identifier' => config(args).deployment_identifier,
            'aws_profile' => config(args).aws_profile,
            'assume_role_arn' => config(args).statebucket_role_arn
          }
        end
      end

      def local_state_path_builder
        lambda do |args|
          Paths.from_project_root_directory(
              'state',
              config(args).deployment_identifier || 'delivery',
              config(args).component,
              'deployment',
              "statebucket.tfstate"
          )
        end
      end

      def config(args)
        configuration.for_overrides(args)
      end

    end
  end
end
