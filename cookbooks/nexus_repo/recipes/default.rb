#
# Cookbook:: nexus_repo
# Recipe:: default
#

# 1. Create nexus group
group node['nexus_repo']['group'] do
  action :create
end

# 2. Create nexus user with shell
user node['nexus_repo']['user'] do
  comment 'Nexus Repository Manager User'
  gid node['nexus_repo']['group']
  system true
  shell '/bin/bash'
  home node['nexus_repo']['home']
  action :create
end

# 3. Install Java
package node['nexus_repo']['java_package'] do
  action :install
end

# Variables for download
nexus_tarball = "nexus-#{node['nexus_repo']['version']}-unix.tar.gz"
nexus_url = "#{node['nexus_repo']['url_base']}/#{nexus_tarball}"
download_path = "#{node['nexus_repo']['tmp_dir']}/#{nexus_tarball}"

# 4. Download Nexus tarball
remote_file download_path do
  source nexus_url
  action :create
end

# 5. Create Nexus directories and Extract Nexus
bash 'extract_nexus' do
  cwd node['nexus_repo']['tmp_dir']
  code <<-EOH
    mkdir -p #{node['nexus_repo']['home']}
    tar -xzf #{download_path} -C #{node['nexus_repo']['home']} --strip-components=1
  EOH
  not_if { ::File.exist?("#{node['nexus_repo']['home']}/bin/nexus") }
end

# 6. Configure nexus.rc
template "#{node['nexus_repo']['home']}/bin/nexus.rc" do
  source 'nexus.rc.erb'
  owner node['nexus_repo']['user']
  group node['nexus_repo']['group']
  mode '0644'
  variables(
    nexus_user: node['nexus_repo']['user']
  )
end

# 7. Change ownership
bash 'chown_nexus' do
  code <<-EOH
    chown -R #{node['nexus_repo']['user']}:#{node['nexus_repo']['group']} #{node['nexus_repo']['home']}
    mkdir -p #{node['nexus_repo']['data_dir']}
    chown -R #{node['nexus_repo']['user']}:#{node['nexus_repo']['group']} #{node['nexus_repo']['data_dir']}
    mkdir -p #{node['nexus_repo']['data_dir']}/etc/fabric
    chown -R #{node['nexus_repo']['user']}:#{node['nexus_repo']['group']} #{node['nexus_repo']['data_dir']}/etc/fabric
    mkdir -p #{node['nexus_repo']['data_dir']}/db_backup
    chown -R #{node['nexus_repo']['user']}:#{node['nexus_repo']['group']} #{node['nexus_repo']['data_dir']}/db_backup
    mkdir -p #{node['nexus_repo']['data_dir']}/db_backup_pro
    chown -R #{node['nexus_repo']['user']}:#{node['nexus_repo']['group']} #{node['nexus_repo']['data_dir']}/db_backup_pro 
  EOH
end

# 8. Modify nexus.vmoptions (comment out endorsed line)
# This is required for Nexus to run with Java 9+
## Configure JVM options. /opt/nexus/bin
template "#{node['nexus_repo']['home']}/bin/nexus.vmoptions" do
  source 'nexus.vmoptions.erb'
  owner node['nexus_repo']['user']
  group node['nexus_repo']['group']
  mode '0644'
  variables(
    data_dir: node['nexus_repo']['data_dir']
  )
end

template "#{node['nexus_repo']['data_dir']}/etc/nexus.properties" do
  source 'nexus.properties.erb'
  owner node['nexus_repo']['user']
  group node['nexus_repo']['group']
  mode '0644'
  variables(
    data_dir: node['nexus_repo']['data_dir']
  )
end

template "#{node['nexus_repo']['data_dir']}/etc/fabric/nexus-store.properties" do
  source 'nexus-store.properties.erb'
  owner node['nexus_repo']['user']
  group node['nexus_repo']['group']
  mode '0644'
  variables(
    data_dir: node['nexus_repo']['data_dir']
  )
end

# 9. Create systemd service file
template "/etc/systemd/system/#{node['nexus_repo']['service_name']}.service" do
  source 'nexus.service.erb'
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    nexus_user: node['nexus_repo']['user'],
    nexus_group: node['nexus_repo']['group'],
    nexus_home: node['nexus_repo']['home']
  )
  notifies :run, 'execute[systemctl-daemon-reload]', :immediately
end

# 10. Install and configure firewalld
package 'firewalld' do
  action :install
end

service 'firewalld' do
  action [:enable, :start]
end

# Open firewall ports for Nexus and Docker
[node['nexus_repo']['port'], node['nexus_repo']['docker_port']].each do |port_to_open|
  execute "open-firewall-port-#{port_to_open}" do
    command "firewall-cmd --add-port=#{port_to_open}/tcp --permanent"
    not_if "firewall-cmd --list-ports | grep -w #{port_to_open}/tcp"
    notifies :run, 'execute[reload-firewalld]', :immediately
  end
end

execute 'reload-firewalld' do
  command 'firewall-cmd --reload'
  action :nothing
end

# 11. Ensure systemd is refreshed before starting Nexus
execute 'systemctl-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

# 12. Enable and start the Nexus service
service node['nexus_repo']['service_name'] do
  action [:enable, :start]
end