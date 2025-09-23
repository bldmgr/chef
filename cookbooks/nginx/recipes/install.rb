#
# Cookbook Name:: nginx
# Recipe:: install
# Author:: 
#
# 'Source' is unsupported because it downloads over plaintext.
#

case node['nginx']['install_method']
  when 'source'
    raise "Nginx source install was removed as downloading plaintext code is insecure."
  when 'package'
    #case node['platform']
    #  when 'redhat','centos','scientific','amazon','oracle'
    #    include_recipe 'fireamp-yum::epel'
    #end
    package 'nginx'
    service 'nginx' do
      supports :status => true, :restart => true, :reload => true
      action :enable
    end
    #include_recipe '::amp_fips'
end

#if amp_feature "lp_42392897_dh_2048_key"
#  cookbook_file '/etc/nginx/dhparams.pem' do
#    source 'dh_pem/dhparams_2048.pem'
#    owner 'nginx'
#    group 'nginx'
#    mode '0440'
#  end
#end

execute 'check nginx syntax' do
  command "/usr/sbin/nginx -t -c #{node['nginx']['dir']}/nginx.conf"
end

service 'nginx' do
  supports :status => true, :restart => true, :reload => true
  action :start
  notifies :run, 'execute[check nginx syntax]', :before
end
