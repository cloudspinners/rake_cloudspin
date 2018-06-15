require 'confidante'
require 'rake_terraform'
require 'rake/tasklib'
require 'aws_ssh_key'
require_relative '../tasklib'
require_relative '../paths'

module RakeCloudspin
  module Tasks
    class BaseStackTasks < TaskLib

      attr_reader :configuration, :stacks, :stack_type, :stacks_with_tests

      def define
        @stacks = if Dir.exist?(stack_type)
          Dir.entries(stack_type).select { |stack|
            File.directory? File.join(stack_type, stack) and File.exists?("#{stack_type}/#{stack}/stack.yaml")
          }
        else
          []
        end

        if @stacks.any?
          @stacks_with_tests = @stacks.select { |stack|
            has_inspec_tests? (stack)
          }
          @configuration = Confidante.configuration

          define_terraform_installation_tasks
          define_top_level_tasks
          define_stack_tasks
        end
      end

      def define_terraform_installation_tasks
        RakeTerraform.define_installation_tasks(
          path: File.join(Dir.pwd, 'vendor', 'terraform'),
          version: '0.11.7'
        )
      end

      def define_stack_tasks
        namespace stack_type do
          stacks.each { |stack|
            namespace stack do
              define_tasks_for_each_stack(stack)
              define_tasks_for_ssh_keys(stack)
              define_tasks_for_stack_tests(stack)
            end
          }
        end
      end

      def define_tasks_for_each_stack(stack)
        RakeTerraform.define_command_tasks do |t|
          t.configuration_name = "#{stack_type}-#{stack}"
          t.source_directory = "#{stack_type}/#{stack}/infra"
          t.work_directory = 'work'

          puts "============================="
          puts "#{stack_type}/#{stack}"
          puts "============================="

          t.state_file = lambda do
            Paths.from_project_root_directory('state', 'example', 'statebucket', 'statebucket.tfstate')
          end

          t.vars = lambda do |args|
            # I don't think this will work:
            configuration
                .for_overrides(args)
                .for_scope(stack_type => stack)
                .vars
          end
          puts "tfvars:"
          puts "---------------------------------------"
          puts "#{t.vars.call({}).to_yaml}"
          puts "---------------------------------------"
        end
      end

      def define_tasks_for_stack_tests(stack)
        if has_inspec_tests? (stack)
          desc 'Run inspec tests'
          task :test do
            create_inspec_attributes(stack)
            run_inspec_profile(stack)
          end
        end
      end

      def has_inspec_tests? (stack)
        Dir.exist? ("#{stack_type}/#{stack}/tests/inspec")
      end

      def create_inspec_attributes(stack)
        mkpath "work/tests/inspec"
        stack_configuration = configuration.for_scope(stack_type => stack)
        File.open("work/tests/inspec/attributes-#{stack_type}-#{stack}.yml", 'w') {|f| 
          f.write({
            'deployment_identifier' => stack_configuration.deployment_identifier,
            'component' => stack_configuration.component,
            'service' => stack,
            'stack' => stack
          }.to_yaml)
        }
      end

      def run_inspec_profile(stack)
        inspec_profiles = Dir.entries("#{stack_type}/#{stack}/tests/inspec").select { |profile|
          profile != '..'
          File.exists? ("#{stack_type}/#{stack}/tests/inspec/#{profile}/inspec.yml")
        }.each { |profile|
          profile_name = profile != '.' ? profile : 'root'
          inspec_cmd = 
            "inspec exec " \
            "#{stack_type}/#{stack}/tests/inspec/#{profile} " \
            "-t aws:// " \
            "--reporter json-rspec:work/tests/inspec/results-#{stack_type}-#{stack}-#{profile_name}.json " \
            "cli " \
            "--attrs work/tests/inspec/attributes-#{stack_type}-#{stack}.yml"
          puts "INSPEC: #{inspec_cmd}"
          system(inspec_cmd)
        }
      end

      def define_tasks_for_ssh_keys(stack)
        stack_configuration = configuration.for_scope(stack_type => stack)

        unless stack_configuration.ssh_keys.nil?
          desc "Ensure ssh keys for #{stack}"
          task :ssh_keys do
            stack_configuration.ssh_keys.each { |ssh_key_name|
              key = AwsSshKey::Key.new(
                key_path: "/#{configuration.estate}/#{configuration.component}/#{stack}/#{configuration.deployment_identifier}/ssh_key",
                key_name: ssh_key_name,
                aws_region: configuration.region,
                tags: {
                  :Estate => configuration.estate,
                  :Component => configuration.component,
                  :Service => stack,
                  :DeploymentIdentifier => configuration.deployment_identifier
                }
              )
              key.load
              key.write("work/#{stack_type}/#{stack}/ssh_keys/")
            }
          end

          task :plan => [ :ssh_keys ]
          task :provision => [ :ssh_keys ]
        end
      end

    end
  end
end

