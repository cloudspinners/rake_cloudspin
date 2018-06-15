require 'confidante'
require 'rake_terraform'
require 'rake/tasklib'
require 'aws_ssh_key'
require_relative '../tasklib'
require_relative '../paths'

module RakeCloudspin
  module Tasks
    class Delivery < TaskLib

      def setup_stack_definitions
        @delivery_stacks = Dir.entries('delivery').select { |stack|
          File.directory? File.join('delivery', stack) and File.exists?("delivery/#{stack}/stack.yaml")
        }
        @stacks_with_tests = @delivery_stacks.select { |delivery_stack|
          has_inspec_tests? (delivery_stack)
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
        define_delivery_namespace
      end

      def define_terraform_installation
        RakeTerraform.define_installation_tasks(
          path: File.join(Dir.pwd, 'vendor', 'terraform'),
          version: '0.11.7'
        )
      end

      def define_top_level_tasks
        desc 'Show the plan for changes to the delivery stacks'
        task :delivery_plan => @delivery_stacks.map { |delivery_stack|
          :"delivery:#{delivery_stack}:plan"
        }

        desc 'Provision the delivery stacks'
        task :delivery_provision => @delivery_stacks.map { |delivery_stack|
          :"delivery:#{delivery_stack}:provision"
        }

        unless @stacks_with_tests.empty?
          desc 'Test the delivery stacks'
          task :delivery_test => @stacks_with_tests.map { |delivery_stack|
            :"delivery:#{delivery_stack}:test"
          }
        end

        desc 'Destroy the delivery stacks'
        task :delivery_destroy => @delivery_stacks.map { |delivery_stack|
          :"delivery:#{delivery_stack}:destroy"
        }
      end

      def define_delivery_namespace
        namespace :delivery do
          @delivery_stacks.each { |delivery_stack|
            namespace delivery_stack do
              define_stack_tasks(delivery_stack)
              define_stack_ssh_key_tasks(delivery_stack)
              define_stack_test_tasks(delivery_stack)
            end
          }
        end
      end

      def define_stack_tasks(delivery_stack)
        RakeTerraform.define_command_tasks do |t|
          t.configuration_name = "delivery-#{delivery_stack}"
          t.source_directory = "delivery/#{delivery_stack}/infra"
          t.work_directory = 'work'

          puts "============================="
          puts "delivery/#{delivery_stack}"
          puts "============================="

          t.state_file = lambda do
            Paths.from_project_root_directory('state', 'example', 'statebucket', 'statebucket.tfstate')
          end

          t.vars = lambda do |args|
            @configuration
                .for_overrides(args)
                .for_scope(delivery: delivery_stack)
                .vars
          end
          puts "tfvars:"
          puts "---------------------------------------"
          puts "#{t.vars.call({}).to_yaml}"
          puts "---------------------------------------"
        end
      end

      def has_inspec_tests? (delivery_stack)
        Dir.exist? ("delivery/#{delivery_stack}/tests/inspec")
      end

      def define_stack_test_tasks(delivery_stack)
        if has_inspec_tests? (delivery_stack)
          stack_configuration = @configuration
            .for_scope(delivery: delivery_stack)

          desc 'Run inspec tests'
          task :test do
            create_inspec_attributes(delivery_stack, stack_configuration)
            run_inspec_profile(delivery_stack)
          end

        end
      end

      def create_inspec_attributes(delivery_stack, stack_configuration)
        mkpath "work/tests/inspec"
        File.open("work/tests/inspec/attributes-delivery-#{delivery_stack}.yml", 'w') {|f| 
          f.write({
            'delivery_identifier' => stack_configuration.delivery_identifier,
            'component' => stack_configuration.component,
            'service' => delivery_stack,
            'delivery_stack' => delivery_stack
          }.to_yaml)
        }
      end

      def run_inspec_profile(delivery_stack)
        inspec_profiles = Dir.entries("delivery/#{delivery_stack}/tests/inspec").select { |profile|
          profile != '..'
          File.exists? ("delivery/#{delivery_stack}/tests/inspec/#{profile}/inspec.yml")
        }.each { |profile|
          profile_name = profile != '.' ? profile : 'root'
          inspec_cmd = 
            "inspec exec " \
            "delivery/#{delivery_stack}/tests/inspec/#{profile} " \
            "-t aws:// " \
            "--reporter json-rspec:work/tests/inspec/results-delivery-#{delivery_stack}-#{profile_name}.json " \
            "cli " \
            "--attrs work/tests/inspec/attributes-delivery-#{delivery_stack}.yml"
          puts "INSPEC: #{inspec_cmd}"
          system(inspec_cmd)
        }
      end

      def define_stack_ssh_key_tasks(delivery_stack)
        stack_configuration = @configuration
          .for_scope(delivery: delivery_stack)

        unless stack_configuration.ssh_keys.nil?

          desc "Ensure ssh keys for #{delivery_stack}"
          task :ssh_keys do
            stack_configuration.ssh_keys.each { |ssh_key_name|
              key = AwsSshKey::Key.new(
                key_path: "/#{@configuration.estate}/#{@configuration.component}/#{delivery_stack}/#{@configuration.delivery_identifier}/ssh_key",
                key_name: ssh_key_name,
                aws_region: @configuration.region,
                tags: {
                  :Estate => @configuration.estate,
                  :Component => @configuration.component,
                  :Service => delivery_stack,
                  :DeploymentIdentifier => @configuration.delivery_identifier
                }
              )
              key.load
              key.write("work/delivery/#{delivery_stack}/ssh_keys/")
            }
          end

          task :plan => [ :ssh_keys ]
          task :provision => [ :ssh_keys ]
        end
      end

    end
  end
end

