#
# Cookbook:: nexus
# Recipe:: default
#
# Copyright:: 2025, bldmgr, All Rights Reserved.
#

# Default attributes - can be overridden in attributes file or role
node.default['nexus']['version'] = '3.70.4-02'
node.default['nexus']['user'] = 'nexus'
node.default['nexus']['group'] = 'nexus'
node.default['nexus']['home'] = '/opt/nexus'
node.default['nexus']['data_dir'] = '/opt/sonatype-work'
node.default['nexus']['port'] = '8081'
node.default['nexus']['context_path'] = '/'
node.default['nexus']['java_opts'] = '-Xms1200m -Xmx1200m -XX:MaxDirectMemorySize=2g'

# Create nexus user and group
group node['nexus']['group'] do
  action :create
end

user node['nexus']['user'] do
  group node['nexus']['group']
  system true
  shell '/bin/bash'
  home node['nexus']['home']
  action :create
end

# 3. Install Java 11
package 'java-11-openjdk' do
  action :install
end

# 4. Download Nexus tarball
remote_file '/tmp/nexus.tar.gz' do
  source 'https://download.sonatype.com/nexus/3/nexus-3.70.4-02-unix.tar.gz'
  action :create
  notifies :run, 'bash[extract_nexus]', :immediately
end

# 5. Extract Nexus
bash 'extract_nexus' do
  cwd '/opt'
  code <<-EOH
    tar -xzf /tmp/nexus.tar.gz
    mv nexus-* nexus
  EOH
  not_if { ::File.exist?('/opt/nexus') }
  action :nothing
  notifies :create, 'file[/opt/nexus/bin/nexus.rc]', :immediately
end

# 6. Configure nexus.rc
file '/opt/nexus/bin/nexus.rc' do
  content 'run_as_user="nexus"'
  owner 'nexus'
  group 'nexus'
  mode '0644'
  action :nothing
  notifies :run, 'bash[chown_nexus]', :immediately
end

# 7. Change ownership
bash 'chown_nexus' do
  code <<-EOH
    chown -R nexus:nexus /opt/nexus
    mkdir -p /opt/sonatype-work
    chown -R nexus:nexus /opt/sonatype-work
  EOH
  action :nothing
  notifies :create, 'template[/etc/systemd/system/nexus.service]', :immediately
end

# 8. Create systemd service file
template '/etc/systemd/system/nexus.service' do
  source 'nexus.service.erb'
  owner 'root'
  group 'root'
  mode '0644'
  action :nothing
end

# 9. Modify nexus.vmoptions (comment out endorsed line)
ruby_block 'Comment out endorsed dirs in vmoptions' do
  block do
    file = Chef::Util::FileEdit.new('/opt/nexus/bin/nexus.vmoptions')
    file.search_file_delete_line(/^.*Djava.endorsed.dirs.*$/)
    file.write_file
  end
  only_if { ::File.exist?('/opt/nexus/bin/nexus.vmoptions') }
end

# 10. Install and configure firewalld
package 'firewalld' do
  action :install
end

service 'firewalld' do
  action [:enable, :start]
end

execute 'open-port-8081' do
  command 'firewall-cmd --add-port=8081/tcp --permanent'
  not_if 'firewall-cmd --list-ports | grep 8081/tcp'
  notifies :run, 'execute[reload-firewalld]', :immediately
end

execute 'reload-firewalld' do
  command 'firewall-cmd --reload'
  action :nothing
end

# 11. Ensure systemd is refreshed before starting Nexus
execute 'systemctl-daemon-reexec' do
  command 'systemctl daemon-reexec'
end

execute 'systemctl-daemon-reload' do
  command 'systemctl daemon-reload'
end

# 12. Enable and start the Nexus service
service 'nexus' do
  action [:enable, :start]
end