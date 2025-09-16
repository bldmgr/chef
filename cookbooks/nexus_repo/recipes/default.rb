# 1. Create nexus group
group 'nexus' do
  action :create
end

# 2. Create nexus user with shell
user 'nexus' do
  comment 'Nexus Repository Manager User'
  gid 'nexus'
  system true
  shell '/bin/bash'
  home '/opt/nexus'
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

# 8. Create systemd service
template '/etc/systemd/system/nexus.service' do
  source 'nexus.service.erb'
  owner 'root'
  group 'root'
  mode '0644'
  action :nothing
  notifies :run, 'execute[systemctl-daemon-reload]', :immediately
end

# 9. Reload systemd and start nexus
execute 'systemctl-daemon-reload' do
  command 'systemctl daemon-reload'
  action :nothing
  notifies :enable, 'service[nexus]', :immediately
  notifies :start, 'service[nexus]', :immediately
end

# 10. Manage nexus service
service 'nexus' do
  action :nothing
end

# 11. Comment out endorsed line in vmoptions
ruby_block 'Comment out endorsed dirs in vmoptions' do
  block do
    file = Chef::Util::FileEdit.new('/opt/nexus/bin/nexus.vmoptions')
    file.search_file_delete_line(/^.*Djava.endorsed.dirs.*$/)
    file.write_file
  end
  only_if { ::File.exist?('/opt/nexus/bin/nexus.vmoptions') }
end

# 12. Install and configure firewall
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

# 13. Reexec systemd (cleanup)
execute 'systemctl-daemon-reexec' do
  command 'systemctl daemon-reexec'
end
