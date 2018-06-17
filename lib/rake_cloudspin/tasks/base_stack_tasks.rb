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
          @configuration = Confidante.configuration(
            :hiera => Hiera.new(config: hiera_file)
          )

          define_terraform_installation_tasks
          define_top_level_tasks
          define_stack_tasks
        end
      end

      def hiera_file
        File.expand_path(File.join(File.dirname(__FILE__), 'hiera.yaml'))
      end

      def stack_configuration(stack, args)
        configuration
            .for_overrides(args)
            .for_scope(stack_type => stack)
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

          # TODO: Handle args that override configuration
          stack_state = stack_configuration(stack, {}).state
          if stack_state.nil? || stack_state[:type].to_s.empty? || stack_state[:type] == 'local'
            add_local_state_configuration(stack, t)
          elsif stack_state[:type] == 's3'
            add_s3_backend_configuration(stack, task)
          else
            raise "ERROR: Unknown stack state type '#{stack_state[:type]}' for #{stack_type} stack '#{stack}'"
          end

          t.vars = lambda do |args|
            puts "Terraform variables:"
            puts "---------------------------------------"
            puts "#{stack_configuration(stack, args).vars.to_yaml}"
            puts "---------------------------------------"
            stack_configuration(stack, args).vars
          end
        end
      end

      def add_local_state_configuration(stack, task)
        puts "INFO: Storing terraform state locally"
        task.state_file = lambda do |args|
          local_statefile_path(stack, args)
        end
      end

      def local_statefile_path(stack, args)
        Paths.from_project_root_directory(
            'state', 
            stack_configuration(stack, args).deployment_identifier || 'component',
            stack_configuration(stack, args).component,
            stack_type,
            "#{stack}.tfstate")
      end

      def add_s3_backend_configuration(stack, task)
        puts "INFO: Storing terraform state in a remote S3 bucket"
        task.backend_config = lambda do |args|
          stack_configuration(stack, args).backend_config
        end
        puts "backend:"
        puts "---------------------------------------"
        puts "#{task.backend_config.call({}).to_yaml}"
        puts "---------------------------------------"
      end

      def define_tasks_for_stack_tests(stack)
        if has_inspec_tests? (stack)
          desc 'Run inspec tests'
          task :test do
            # TODO: Handle args that override configuration
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
        File.open("work/tests/inspec/attributes-#{stack_type}-#{stack}.yml", 'w') {|f| 
          f.write({
            'deployment_identifier' => stack_configuration(stack, {}).deployment_identifier,
            'component' => stack_configuration(stack, {}).component,
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
        # TODO: Handle args that override configuration
        ssh_keys_config = stack_configuration(stack, {}).ssh_keys

        unless ssh_keys_config.nil?
          desc "Ensure ssh keys for #{stack}"
          task :ssh_keys do
            ssh_keys_config.each { |ssh_key_name|
              key = AwsSshKey::Key.new(
                key_path: "/#{stack_configuration(stack, {}).estate}/#{stack_configuration(stack, {}).component}/#{stack}/#{stack_configuration(stack, {}).deployment_identifier}/ssh_key",
                key_name: ssh_key_name,
                aws_region: stack_configuration(stack, {}).region,
                tags: {
                  :Estate => stack_configuration(stack, {}).estate,
                  :Component => stack_configuration(stack, {}).component,
                  :Service => stack,
                  :DeploymentIdentifier => stack_configuration(stack, {}).deployment_identifier
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

