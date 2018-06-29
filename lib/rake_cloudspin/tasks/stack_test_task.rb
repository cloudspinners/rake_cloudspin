
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
        attributes = stack_config(args).vars
      end

      def run_inspec_profile
        lambda do |args|
          inspec_profiles = Dir.entries("#{stack_type}/#{stack_name}/tests/inspec").select { |profile|
            profile != '..'
            File.exists? ("#{stack_type}/#{stack_name}/tests/inspec/#{profile}/inspec.yml")
          }.each { |profile|
            profile_name = profile != '.' ? profile : '__root__'
            puts "INSPEC (profile '#{profile_name}'): #{inspec_cmd(profile, profile_name)}"
            system(inspec_cmd(profile, profile_name))
          }
        end
      end

      def inspec_cmd(profile, profile_name)
          "inspec exec " \
          "#{stack_type}/#{stack_name}/tests/inspec/#{profile} " \
          "-t aws:// " \
          "--reporter json-rspec:work/tests/inspec/results-#{stack_type}-#{stack_name}-#{profile_name}.json " \
          "cli " \
          "--attrs work/tests/inspec/attributes-#{stack_type}-#{stack_name}.yml"
      end

    end
  end
end
