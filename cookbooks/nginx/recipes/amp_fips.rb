if amp_feature 'jira_OPSENG_3727_enable_amp_fips_nginx'
  include_recipe 'fireamp-yum::web_gov_nexus'

  package 'amp-fips-nginx'

  template '/etc/sysconfig/nginx' do
    source 'nginx.sysconfig.erb'
    owner  'root'
    group  'root'
    mode   '0644'
    notifies :restart, 'service[nginx]', :delayed
  end

  # Install the new startup script
  if node.centos7?
    execute 'nginx daemon reload' do
      command 'systemctl daemon-reload'
      action  :nothing
    end

    template '/usr/lib/systemd/system/nginx.service' do
      source 'nginx.service.erb'
      owner  'root'
      group  'root'
      mode   '0755'
      variables(
        src_binary: '/opt/amp_fips/embedded/sbin/nginx'
      )
      notifies :run, 'execute[nginx daemon reload]', :immediately
      notifies :restart, 'service[nginx]', :delayed
    end
  else
    raise "Platform/version is not valid: #{node['platform']}:#{node['platform_version']}"
  end
end
