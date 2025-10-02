#
# Cookbook:: nexus_repo
# Attributes:: default
#

# Nexus version and download settings
default['nexus_repo']['version'] = '3.70.4-02'
default['nexus_repo']['url_base'] = 'https://download.sonatype.com/nexus/3'

# User and group settings
default['nexus_repo']['user'] = 'nexus'
default['nexus_repo']['group'] = 'nexus'

# Directory settings
default['nexus_repo']['home'] = '/opt/nexus'
default['nexus_repo']['data_dir'] = '/data/nexus'
default['nexus_repo']['tmp_dir'] = 'tmp'

# Java settings
default['nexus_repo']['java_package'] = 'java-11-openjdk'

# Network settings
default['nexus_repo']['port'] = '8081'
default['nexus_repo']['docker_port'] = '8082'

# Service settings
default['nexus_repo']['service_name'] = 'nexus'