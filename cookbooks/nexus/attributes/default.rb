# attributes/default.rb
# Nexus version and download settings
default['nexus']['version'] = '3.45.0-01'
default['nexus']['checksum'] = nil # Add checksum for security if needed

# User and group settings
default['nexus']['user'] = 'nexus'
default['nexus']['group'] = 'nexus'

# Directory settings
default['nexus']['home'] = '/opt/nexus'
default['nexus']['data_dir'] = '/opt/sonatype-work'

# Network settings
default['nexus']['port'] = '8081'
default['nexus']['host'] = '0.0.0.0'
default['nexus']['context_path'] = '/'

# JVM settings
default['nexus']['java_opts'] = '-Xms1200m -Xmx1200m -XX:MaxDirectMemorySize=2g'

# Service settings
default['nexus']['service_timeout'] = 600

# Security settings
default['nexus']['configure_firewall'] = true