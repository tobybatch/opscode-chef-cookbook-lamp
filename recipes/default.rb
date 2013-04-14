include_recipe "apache2"
include_recipe "php"
include_recipe "mysql::client"
include_recipe "mysql::server"
include_recipe "php::module_mysql"
include_recipe "php::module_curl"
include_recipe "php::module_gd"
include_recipe "apache2::mod_php5"
include_recipe "apache2::mod_rewrite"

if node[:lamp]
    node[:lamp][:sites].each do |site|
        git_root  = "/var/www/#{site[:name]}/"
        document_root  = "#{git_root}application/webroot"

        directory "/var/www/#{site[:name]}/" do
            user "ubuntu"
            group "ubuntu"
        end

        web_app site[:name] do
            server_name site[:name]
            server_aliases site[:aliases]
            docroot document_root
        end

        if site[:deploy][:ssh_wrapper]
            ssh_wrapper_file = "/home/ubuntu/.gitssh_#{site[:name]}"
            rsa_key = data_bag_item('credentials', 'private_keys')[site[:name]]
            
            file "/home/ubuntu/.ssh/id_rsa_#{site[:name]}" do
                content rsa_key
                user "ubuntu"
                group "ubuntu"
                mode 00600
            end

            file ssh_wrapper_file do
                content "exec ssh -o UserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no -i \"/home/ubuntu/.ssh/id_rsa_#{site[:name]}\" \"$@\""
                user "ubuntu"
                group "ubuntu"
                mode 00755
            end
        end

        if site[:deploy]
            git git_root do
                repository site[:deploy][:repo]
                user "ubuntu"
                group "ubuntu"
                enable_submodules true
                if site[:deploy][:ssh_wrapper]
                    ssh_wrapper ssh_wrapper_file
                end
            end
        end
    end
end
