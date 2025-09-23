#
# Cookbook Name:: nginx
# Recipe:: default
# Author:: AJ Christensen <aj@junglist.gen.nz>
#
# Copyright 2008-2012, Opscode, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

include_recipe 'nginx::ohai_plugin'
include_recipe 'nginx::install'

case node['nginx']['install_method']
  when 'package'
    include_recipe 'nginx::commons'
end

#if chef17up?
node.default['audit']['compliance_phase'] = true
include_profile 'nginx::nginx'
#else
#  control_group "nginx cookbook" do
#    control "default recipe" do
#      it "installs nginx" do
#        expect(package("nginx")).to be_installed
#      end
#      it "runs a service named nginx" do
#        `service nginx status`
#        expect($?).to be_success
#      end
#    end
#  end
#end
