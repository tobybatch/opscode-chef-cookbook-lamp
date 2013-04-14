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
        directory "/var/www/#{site[:name]}/" do
            user "ubuntu"
            group "ubuntu"
        end

        web_app site[:name] do
            server_name site[:name]
            server_aliases site[:aliases]
            docroot "/var/www/#{site[:name]}/application/webroot"
        end
    end
end
