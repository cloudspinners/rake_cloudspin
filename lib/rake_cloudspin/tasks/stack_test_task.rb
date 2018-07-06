
module RakeCloudspin
  module Tasks
    class StackTestTask < BaseTask

      parameter :stack_name
      parameter :stack_type

      def define
        define_inspec_task
        define_aws_configuration_task
      end

      def define_inspec_task
        desc 'Run inspec tests'
        task :test do |t, args|
          if has_inspec_tests?
            create_inspec_attributes.call(args)
            run_inspec_profile.call(args)
          else
            puts "NO TESTS FOR STACK ('#{stack_name}')"
          end
        end
      end

      def has_inspec_tests?
        Dir.exist? ("#{stack_type}/#{stack_name}/tests/inspec")
      end

      def create_inspec_attributes
        lambda do |args|
          mkpath "work/tests/inspec"
          attributes_file_path = "work/tests/inspec/attributes-#{stack_type}-#{stack_name}.yml"
          puts "INFO: Writing inspec attributes to file: #{attributes_file_path}"
          File.open(attributes_file_path, 'w') {|f| 
            f.write(test_attributes(args).to_yaml)
          }
        end
      end

      def test_attributes(args)
        fix_user_list(stack_config(args).vars.merge(test_vars(args)))
      end

      def test_vars(args)
        stack_config(args).test_vars || {}
      end

      def fix_user_list(var_hash)
        var_hash.each { |name, value|
          if name == 'api_users'
            var_hash[name] = JSON.parse(value)
          end
        }
        var_hash
      end

      def define_aws_configuration_task
        task :aws_configuration do |t, args|
          make_aws_configuration_file.call(args)
        end
      end

      def make_aws_configuration_file
        lambda do |args|
          mkpath aws_configuration_folder
          puts "INFO: Writing AWS configuration file: #{aws_configuration_file_path}"
          File.open(aws_configuration_file_path, 'w') {|f| 
            f.write(aws_configuration_contents(args))
          }
        end
      end

      def aws_configuration_folder
        "work/#{stack_type}/#{stack_name}/aws"
      end

      def aws_configuration_file_path
        "#{aws_configuration_folder}/config"
      end

      def aws_configuration_contents(args)
        <<~END_AWS_CONFIG
          [profile #{assume_role_profile(args)}]
          role_arn = #{stack_config(args).vars['assume_role_arn']}
          source_profile = #{stack_config(args).vars['aws_profile']}
        END_AWS_CONFIG
      end

      def assume_role_profile(args)
        "assume-spin_account_manager-#{stack_config(args).component}"
      end

      def run_inspec_profile
        lambda do |args|
          inspec_profiles = Dir.entries("#{stack_type}/#{stack_name}/tests/inspec").select { |inspec_profile|
            inspec_profile != '..' &&
              File.exists?("#{stack_type}/#{stack_name}/tests/inspec/#{inspec_profile}/inspec.yml")
          }.each { |inspec_profile|
            inspec_profile_name = make_inspec_profile_name(inspec_profile)
            puts "INSPEC (inspec_profile '#{inspec_profile_name}'): #{inspec_cmd(
              inspec_profile: inspec_profile,
              inspec_profile_name: inspec_profile_name,
              aws_profile: assume_role_profile(args),
              aws_region: stack_config(args).region
            )}"
            system(
              inspec_cmd(
                  inspec_profile: inspec_profile,
                  inspec_profile_name: inspec_profile_name,
                  aws_profile: assume_role_profile(args),
                  aws_region: stack_config(args).region
              )
            )
          }
        end
      end

      def make_inspec_profile_name(inspec_profile)
        inspec_profile != '.' ? inspec_profile : '__root__'
      end

      def inspec_cmd(inspec_profile:, inspec_profile_name:, aws_profile:, aws_region:)
          "inspec exec " \
          "#{stack_type}/#{stack_name}/tests/inspec/#{inspec_profile} " \
          "-t aws://#{aws_region}/#{aws_profile} " \
          "--reporter json-rspec:work/tests/inspec/results-#{stack_type}-#{stack_name}-#{inspec_profile_name}.json " \
          "cli " \
          "--attrs work/tests/inspec/attributes-#{stack_type}-#{stack_name}.yml"
      end

    end
  end
end
