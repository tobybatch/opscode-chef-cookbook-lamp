include_recipe "apache2"
include_recipe "php"
include_recipe "mysql::client"
include_recipe "mysql::server"
include_recipe "php::module_mysql"
include_recipe "php::module_curl"
include_recipe "php::module_gd"
include_recipe "apache2::mod_php5"
include_recipe "apache2::mod_rewrite"
include_recipe "git-deploy"

if node[:lamp]
  node[:lamp].each do |name, site|
    document_root  = "/var/www/#{name}/application/webroot"

    web_app name do
      server_name name
      server_aliases site[:aliases]
      docroot document_root
    end
  end
end
