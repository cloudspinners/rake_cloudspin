
module RakeCloudspin
  module Tasks
    class BaseTask < TaskLib

      parameter :configuration, :required => true
      parameter :stack_name, :required => true
      parameter :stack_type, :required => true

      def stack_config(args = {})
        configuration
          .for_overrides(args)
          .for_scope(stack_type => stack_name)
      end

      def spin_user_variables(args)
        user_variables_hash = {
          'spin_api_users' => []
        }
        api_users = stack_config(args).api_users
        api_users.each { |user_name, user_configuration|
          user_variables_hash['spin_api_users'] << user_name
          if user_configuration.key?('roles')
            user_configuration['roles'].each { |role_name|
              unless user_variables_hash.key?(role_user_variable_name(role_name))
                user_variables_hash[role_user_variable_name(role_name)] = []
              end
              user_variables_hash[role_user_variable_name(role_name)] << user_name
            }
          end
        }
        user_variables_hash.each { |var_name, value_list|
          user_variables_hash[var_name].uniq!
        }
        user_variables_hash
      end

      def role_user_variable_name(role_name)
        "#{role_name}-users"
      end

    end
  end
end
