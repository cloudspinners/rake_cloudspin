
module RakeCloudspin
  module Tasks
    class StackTestTask < BaseTask

      parameter :stack_name
      parameter :stack_type

      def define
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
        attributes = stack_config(args).vars.merge(stack_config(args).test_vars)
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
              aws_profile: aws_profile(inspec_profile, args),
              aws_region: stack_config(args).region
            )}"
            puts "Inspec should use aws_profile: #{aws_profile(inspec_profile, args)}"
            system(inspec_cmd(
              inspec_profile: inspec_profile,
              inspec_profile_name: inspec_profile_name,
              aws_profile: aws_profile(inspec_profile, args),
              aws_region: stack_config(args).region
            ))
          }
        end
      end

      def make_inspec_profile_name(inspec_profile)
        inspec_profile != '.' ? inspec_profile : '__root__'
      end

      def aws_profile(inspec_profile, args)
        aws_creds_hash = stack_config(args).inspec['aws_profile']
        if aws_creds_hash[inspec_profile].to_s.empty?
          if aws_creds_hash['default'].to_s.empty?
            'default'
          else
            aws_creds_hash['default']
          end
        else
          aws_creds_hash[inspec_profile]
        end
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
