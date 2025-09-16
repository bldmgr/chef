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

# Install Java (required for Nexus)
package 'java-11-openjdk' do
  action :install
end

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

# Create directories
[node['nexus']['home'], node['nexus']['data_dir']].each do |dir|
  directory dir do
    owner node['nexus']['user']
    group node['nexus']['group']
    mode '0755'
    recursive true
    action :create
  end
end

# Download and extract Nexus
nexus_package = "nexus-#{node['nexus']['version']}-unix.tar.gz"
nexus_url = "https://download.sonatype.com/nexus/3/#{nexus_package}"

remote_file "#{Chef::Config[:file_cache_path]}/#{nexus_package}" do
  source nexus_url
  mode '0644'
  action :create
  not_if { ::File.exist?("#{node['nexus']['home']}/bin/nexus") }
end

# Extract Nexus
execute 'extract_nexus' do
  command <<-EOH
    tar -xzf #{Chef::Config[:file_cache_path]}/#{nexus_package} -C /tmp
    cp -r /tmp/nexus-#{node['nexus']['version']}/* #{node['nexus']['home']}/
    chown -R #{node['nexus']['user']}:#{node['nexus']['group']} #{node['nexus']['home']}
    chown -R #{node['nexus']['user']}:#{node['nexus']['group']} #{node['nexus']['data_dir']}
  EOH
  not_if { ::File.exist?("#{node['nexus']['home']}/bin/nexus") }
end

## Configure Nexus properties
#template "#{node['nexus']['home']}/etc/nexus-default.properties" do
#  source 'nexus-default.properties.erb'
#  owner node['nexus']['user']
#  group node['nexus']['group']
#  mode '0644'
#  variables(
#    port: node['nexus']['port'],
#    context_path: node['nexus']['context_path']
#  )
#  notifies :restart, 'service[nexus]', :delayed
#end

## Configure JVM options
#template "#{node['nexus']['home']}/bin/nexus.vmoptions" do
#  source 'nexus.vmoptions.erb'
#  owner node['nexus']['user']
#  group node['nexus']['group']
#  mode '0644'
#  variables(
#    java_opts: node['nexus']['java_opts'],
#    data_dir: node['nexus']['data_dir']
#  )
#  notifies :restart, 'service[nexus]', :delayed
#end

# Create systemd service file
template '/etc/systemd/system/nexus.service' do
  source 'nexus.service.erb'
  mode '0644'
  variables(
    nexus_user: node['nexus']['user'],
    nexus_home: node['nexus']['home']
  )
  notifies :run, 'execute[systemd_reload]', :immediately
  notifies :restart, 'service[nexus]', :delayed
end

# Reload systemd
execute 'systemd_reload' do
  command 'systemctl daemon-reload'
  action :nothing
end

# Configure firewall (if ufw is available)
execute 'configure_firewall' do
  command "ufw allow #{node['nexus']['port']}"
  only_if 'which ufw'
  not_if "ufw status | grep #{node['nexus']['port']}"
end

# Start and enable Nexus service
service 'nexus' do
  action [:enable, :start]
  supports restart: true, status: true
end

## Wait for Nexus to be ready
#ruby_block 'wait_for_nexus' do
#  block do
#    require 'net/http'
#    require 'uri'
#    
#    uri = URI("http://localhost:#{node['nexus']['port']}")
#    timeout = 300 # 5 minutes
#    start_time = Time.now
#    
#    loop do
#      begin
#        response = Net::HTTP.get_response(uri)
#        if response.code == '200'
#          Chef::Log.info('Nexus is ready!')
#          break
#        end
#      rescue => e
#        Chef::Log.info("Waiting for Nexus to start: #{e.message}")
#      end
#      
#      if Time.now - start_time > timeout
#        raise 'Nexus failed to start within timeout period'
#      end
#      
#      sleep 10
#    end
#  end
#end
#
## Display default admin password location
#ruby_block 'display_admin_info' do
#  block do
#    admin_password_file = "#{node['nexus']['data_dir']}/nexus3/admin.password"
#    if ::File.exist?(admin_password_file)
#      Chef::Log.info("Nexus installation completed!")
#      Chef::Log.info("Default admin password can be found at: #{admin_password_file}")
#      Chef::Log.info("Access Nexus at: http://localhost:#{node['nexus']['port']}")
#    end
#  end
#end