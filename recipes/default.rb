include_recipe "git"
include_recipe "apt"
include_recipe "ark"
include_recipe "curl"
include_recipe "xhprof"
include_recipe "java"

include_recipe "php"
include_recipe "php::module_mysql"
include_recipe "php::module_curl"
include_recipe "php::module_gd"

include_recipe "apache2"
include_recipe "apache2::mod_php5"
include_recipe "apache2::mod_rewrite"

include_recipe "composer"

package "sendmail"
package "vim"
package "libmysql-java" # for liquibase
package "php5-mcrypt"   # for composer

project = node[:project]
repo_directory = "/var/www/#{project}"

credentials = data_bag_item('credentials', node.chef_environment)

if node.chef_environment == "development" then
  node.default["mysql"]["tunable"]["connect_timeout"] = "3600"
  node.default["mysql"]["tunable"]["net_read_timeout"] = "3600"
  node.default["mysql"]["tunable"]["wait_timeout"] = "3600"
  node.default['mysql']['tunable']['max_allowed_packet']   = "256M"
  
  node.override["mysql"]["server_root_password"] = credentials['database']['pass']

  include_recipe "mysql::server"
  include_recipe "mysql::client"
  
  execute "mysql -u root -e \"create database #{project};\" && mysql #{project} -u root < schema.sql" do
    cwd repo_directory
    not_if "if [ -z \"`mysql -u root -e \\\"show databases like '#{project}'\\\"`\" ]; then exit 1; fi"
  end 
  
  remote_file "#{repo_directory}/tests/lib/jasmine.js" do
    source "https://s3.amazonaws.com/daftlabs-assets/jasmine/jasmine.js"
    action :create
  end

  remote_file "#{repo_directory}/tests/lib/console.js" do
    source "https://s3.amazonaws.com/daftlabs-assets/jasmine/console.js"
    action :create
  end 

  package "chrpath"

  ark "phantomjs" do
    action :install
    has_binaries ['bin/phantomjs']
    url "https://s3.amazonaws.com/daftlabs-assets/phantomjs-1.9.7-linux-x86_64.tar.bz2"
    not_if "which phantomjs"
  end
end

ark "liquibase" do
  path repo_directory
  action :put
  url "https://s3.amazonaws.com/daftlabs-assets/liquibase-3.1.1.tar.gz"
  strip_components 0
end

liquibase_command = "java -jar #{repo_directory}/liquibase/liquibase.jar "\
          "--changeLogFile=#{repo_directory}/changes.sql "\
          "--url=jdbc:mysql://#{credentials['database']['host']}/#{credentials['database']['name']} "\
          "--classpath=/usr/share/java/mysql-connector-java.jar "\
          "--username=#{credentials['database']['user']} "\
          "--password=#{credentials['database']['pass']} "\
          "update"

execute liquibase_command do
  cwd "#{repo_directory}/liquibase"
end

template "/etc/apache2/sites-available/#{project}" do
  source "vhost.erb"
  mode 0644
  variables(
    :repo_directory => repo_directory
  )
  notifies :restart, resources(:service => "apache2")
end

execute "a2ensite #{project}" do
  notifies :restart, resources(:service => "apache2")
  not_if do File.symlink?("/etc/apache2/sites-enabled/#{project}") end
end
