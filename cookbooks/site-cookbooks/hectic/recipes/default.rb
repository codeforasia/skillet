require 'chef-deploy'
require 'pathname'

execute "create #{node[:hectic][:database]} database" do
  command "/usr/bin/mysqladmin -u root -p#{node[:mysql][:server_root_password]} create #{node[:hectic][:database]}"
  not_if  "/usr/bin/mysqlshow  -u root -p#{node[:mysql][:server_root_password]} | grep #{node[:hectic][:database]}"
end

[ "#{node[:hectic][:deploy_to]}",
  "#{node[:hectic][:deploy_to]}/releases",
  "#{node[:hectic][:deploy_to]}/shared",
  "#{node[:hectic][:deploy_to]}/shared/config",
  "#{node[:hectic][:deploy_to]}/shared/log",
  "#{node[:hectic][:deploy_to]}/shared/pids"].each do |path|
  directory path do
    recursive true
    owner node[:apache][:user]
    group node[:apache][:user]
    mode 0755
  end
end

template "#{node[:hectic][:deploy_to]}/shared/config/database.yml" do
  source 'database.yml.erb'
  owner node[:apache][:user]
  group node[:apache][:user]
  mode 0600
  variables Hectic.database_config(node)
end

# Include gem dependencies here because of a bug in chef-deploy: the code that
# reads gems.yml references Chef::Exception, but it should be
# Chef::Exceptions, with an s on the end. And I kind of felt a little weird
# about the yaml file anyway.
gem_package 'haml'

deploy node[:hectic][:deploy_to] do
  repo 'git://github.com/matthewtodd/hectic.git'
  revision node[:hectic][:revision]
  migrate true
  migration_command 'rake db:migrate'
  environment node[:hectic][:environment]
  restart_command 'touch tmp/restart.txt'
  user node[:apache][:user]
  group node[:apache][:user]

  current_revision_file = Pathname.new(node[:hectic][:deploy_to]).join('current', 'REVISION')
  current_revision = current_revision_file.exist? ? current_revision_file.read.strip : 'NEVER DEPLOYED'
  action (current_revision == node[:hectic][:revision]) ? :nothing : :deploy
end

web_app 'hectic' do
  docroot "#{node[:hectic][:deploy_to]}/current/public"
  server_name node[:hectic][:server_name]
  server_aliases node[:hectic][:server_aliases]
  rails_env node[:hectic][:environment]
  template 'hectic_web_app.conf.erb'
end

apache_site '000-default' do
  enable false
end

# TODO schedule database backups?