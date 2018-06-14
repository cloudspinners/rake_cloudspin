require 'confidante'
require 'rake_terraform'
require 'rake/tasklib'
require 'aws_ssh_key'
require_relative '../tasklib'
require_relative '../paths'

module RakeCloudspin
  module Tasks
    class Deployment < TaskLib

      def setup_stack_definitions
        @deployment_stacks = Dir.entries('deployment').select { |stack|
          File.directory? File.join('deployment', stack) and File.exists?("deployment/#{stack}/stack.yaml")
        }
      end

      def setup_configuration
        @configuration = Confidante.configuration
      end

      def define
        setup_stack_definitions
        setup_configuration
        define_terraform_installation
        define_top_level_tasks
        define_deployment_namespace
      end

      def define_terraform_installation
        RakeTerraform.define_installation_tasks(
          path: File.join(Dir.pwd, 'vendor', 'terraform'),
          version: '0.11.7'
        )
      end

      def define_top_level_tasks
        desc 'Show the plan for changes to the deployment stacks'
        task :plan => @deployment_stacks.map { |deployment_stack|
          :"deployment:#{deployment_stack}:plan"
        }

        desc 'Provision the deployment stacks'
        task :provision => @deployment_stacks.map { |deployment_stack|
          :"deployment:#{deployment_stack}:provision"
        }

        desc 'Destroy the deployment stacks'
        task :destroy => @deployment_stacks.map { |deployment_stack|
          :"deployment:#{deployment_stack}:destroy"
        }
      end

      def define_deployment_namespace
        namespace :deployment do
          @deployment_stacks.each { |deployment_stack|
            namespace deployment_stack do
              define_stack_tasks(deployment_stack)
              define_stack_ssh_key_tasks(deployment_stack)
              define_stack_test_tasks(deployment_stack)
            end
          }
        end
      end

      def define_stack_tasks(deployment_stack)
        RakeTerraform.define_command_tasks do |t|
          t.configuration_name = "deployment-#{deployment_stack}"
          t.source_directory = "deployment/#{deployment_stack}/infra"
          t.work_directory = 'work'

          puts "============================="
          puts "deployment/#{deployment_stack}"
          puts "============================="

          t.state_file = lambda do
            Paths.from_project_root_directory('state', 'example', 'statebucket', 'statebucket.tfstate')
          end

          t.vars = lambda do |args|
            @configuration
                .for_overrides(args)
                .for_scope(deployment: deployment_stack)
                .vars
          end
          puts "tfvars:"
          puts "---------------------------------------"
          puts "#{t.vars.call({}).to_yaml}"
          puts "---------------------------------------"
        end
      end

      def define_stack_test_tasks(deployment_stack)
        if Dir.exist? ("deployment/#{deployment_stack}/tests/inspec")

          stack_configuration = @configuration
            .for_scope(deployment: deployment_stack)

          desc 'Run inspec tests'
          task :test do
            mkpath "work/tests/inspec"
            File.open("work/tests/inspec/attributes-deployment-#{deployment_stack}.yml", 'w') {|f| 
              f.write({
                'deployment_identifier' => stack_configuration.deployment_identifier,
                'component' => stack_configuration.component,
                'service' => deployment_stack,
                'deployment_stack' => deployment_stack
              }.to_yaml)
            }

            inspec_cmd = 
              "inspec exec " \
              "deployment/#{deployment_stack}/tests/inspec/infrastructure " \
              "-t aws:// " \
              "--reporter json-rspec:work/tests/inspec/results-deployment-#{deployment_stack}.json " \
              "cli " \
              "--attrs work/tests/inspec/attributes-deployment-#{deployment_stack}.yml"
            puts "INSPEC: #{inspec_cmd}"
            system(inspec_cmd)
          end
        end
      end

      def define_stack_ssh_key_tasks(deployment_stack)
        stack_configuration = @configuration
          .for_scope(deployment: deployment_stack)

        unless stack_configuration.ssh_keys.nil?

          desc "Ensure ssh keys for #{deployment_stack}"
          task :ssh_keys do
            stack_configuration.ssh_keys.each { |ssh_key_name|
              key = AwsSshKey::Key.new("/#{@configuration.estate}/#{@configuration.component}/#{deployment_stack}/#{@configuration.deployment_identifier}/ssh_key",
                ssh_key_name, 
                @configuration.region)
              key.load
              key.write("work/deployment/#{deployment_stack}/ssh_keys/")
            }
          end

          task :plan => [ :ssh_keys ]
          task :provision => [ :ssh_keys ]
        end
      end

    end
  end
end

