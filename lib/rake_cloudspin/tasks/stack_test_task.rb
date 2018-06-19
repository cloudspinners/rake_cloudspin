
module RakeCloudspin
  module Tasks
    class StackTestTask < BaseTask

      def define
        desc 'Run inspec tests'
        task :test do
          if has_inspec_tests?
            # TODO: Handle args that override configuration
            create_inspec_attributes
            run_inspec_profile
          else
            puts "NO TESTS FOR STACK ('#{stack_name}')"
          end
        end
      end

      def has_inspec_tests?
        Dir.exist? ("#{stack_type}/#{stack_name}/tests/inspec")
      end

      def create_inspec_attributes
        # TODO: Use args as overrides, so deployment_identifier will actually work
        mkpath "work/tests/inspec"
        File.open("work/tests/inspec/attributes-#{stack_type}-#{stack_name}.yml", 'w') {|f| 
          f.write({
            'deployment_identifier' => stack_config().deployment_identifier,
            'component' => stack_config().component,
            'service' => stack_name,
            'stack_name' => stack_name
          }.to_yaml)
        }
      end

      def run_inspec_profile
        inspec_profiles = Dir.entries("#{stack_type}/#{stack_name}/tests/inspec").select { |profile|
          profile != '..'
          File.exists? ("#{stack_type}/#{stack_name}/tests/inspec/#{profile}/inspec.yml")
        }.each { |profile|
          profile_name = profile != '.' ? profile : 'root'
          puts "INSPEC (profile '#{profile_name}'): #{inspec_cmd(profile_name)}"
          system(inspec_cmd(profile_name))
        }
      end

      def inspec_cmd(profile_name)
          "inspec exec " \
          "#{stack_type}/#{stack_name}/tests/inspec/#{profile_name} " \
          "-t aws:// " \
          "--reporter json-rspec:work/tests/inspec/results-#{stack_type}-#{stack_name}-#{profile_name}.json " \
          "cli " \
          "--attrs work/tests/inspec/attributes-#{stack_type}-#{stack_name}.yml"
      end

    end
  end
end
