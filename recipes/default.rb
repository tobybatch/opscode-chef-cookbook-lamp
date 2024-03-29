include_recipe "apt"
include_recipe "ark"
include_recipe "curl"
include_recipe "java"

include_recipe "php"
include_recipe "php::module_mysql"
include_recipe "php::module_curl"
include_recipe "php::module_gd"

include_recipe "apache2"
include_recipe "apache2::mod_php5"
include_recipe "apache2::mod_rewrite"

package "sendmail"
package "vim"
package "libmysql-java" # for liquibase
package "php5-mcrypt"   # for composer
execute "php5enmod mcrypt"

include_recipe "composer"

project = node[:project]
repo_directory = "/var/www/#{project}"

if node.has_key?('local_database') and node.local_database then
  node.default["mysql"]["tunable"]["connect_timeout"] = "3600"
  node.default["mysql"]["tunable"]["net_read_timeout"] = "3600"
  node.default["mysql"]["tunable"]["wait_timeout"] = "3600"
  node.default['mysql']['tunable']['max_allowed_packet']   = "256M"
  node.default['mysql']['bind_address']   = "localhost"
  
  node.override["mysql"]["server_root_password"] = node.database.pass

  include_recipe "mysql::server"
  include_recipe "mysql::client"

  file "#{repo_directory}/schema.sql" do
    not_if do
      File.exists?("#{repo_directory}/schema.sql")
    end
  end
  
  execute "mysql -u root -e \"create database #{project};\" && mysql #{project} -u root < schema.sql" do
    cwd repo_directory
    not_if "if [ -z \"`mysql -u root -e \\\"show databases like '#{project}'\\\"`\" ]; then exit 1; fi"
  end 
end
  
if node.has_key?('include_testing') and node.include_testing then

  php_pear "xhprof" do
    zend_extensions ['xhprof.so']
    preferred_state "beta"
    action :install
    directives(
      "xhprof.output_dir" => "/tmp"
    )
    notifies :restart, resources(:service => "apache2")
  end

  php_pear "xdebug" do
    zend_extensions ['xdebug.so']
    action :install
    directives(
      :remote_enable => "on",
      :remote_connect_back => "on",
      :idekey => "vagrant",
      :var_display_max_children => -1,
      :var_display_max_data => -1,
      :var_display_max_depth => -1
    )
    notifies :restart, resources(:service => "apache2")
  end

  file "#{repo_directory}/tests/lib/.gitkeep" do
    not_if do
      File.exists?("#{repo_directory}/tests/lib/.gitkeep")
    end
  end
  
  include_recipe "tests"

  file "#{repo_directory}/tests/data.sql" do
    not_if do
      File.exists?("#{repo_directory}/tests/data.sql")
    end
  end

  execute "mysql #{project} -u root < data.sql" do
    cwd "#{repo_directory}/tests"
  end

  package "chrpath"
end

ark "liquibase" do
  path repo_directory
  action :put
  url "https://s3.amazonaws.com/daftlabs-assets/liquibase-3.1.1.tar.gz"
  strip_components 0
end

file "#{repo_directory}/changes.sql" do
  content "--liquibase formatted sql"
  not_if do
    File.exists?("#{repo_directory}/changes.sql")
  end
end

if node.has_key?('database') then
  liquibase_command = "java -jar #{repo_directory}/liquibase/liquibase.jar "\
            "--changeLogFile=#{repo_directory}/changes.sql "\
            "--url=jdbc:mysql://#{node.database.host}/#{node.database.name} "\
            "--classpath=/usr/share/java/mysql-connector-java.jar "\
            "--username=#{node.database.user} "\
            "--password=#{node.database.pass} "\
            "update"

  execute liquibase_command do
    cwd "#{repo_directory}/liquibase"
  end
end

template "/etc/apache2/sites-available/#{project}.conf" do
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
