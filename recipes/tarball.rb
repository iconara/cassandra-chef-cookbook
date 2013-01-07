#
# Cookbook Name:: cassandra-server
# Recipe:: tarball
# Copyright 2012, Michael S. Klishin <michaelklishin@me.com>
# Copyright 2013, Theo Hultberg <theo@iconara.net>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

require 'tmpdir'


include_recipe 'java'
include_recipe 'python'

user node.cassandra.user do
  comment "Cassandra Server user"
  home    node.cassandra.installation_dir
  shell   "/bin/bash"
  action  :create
end

group node.cassandra.user do
  members [node.cassandra.user]
  action :create
end

tarball_path = File.join(Dir.tmpdir, 'apache-cassandra.tar.gz')

remote_file tarball_path do
  source node.cassandra.tarball.url
  not_if 'which cassandra'
end

execute 'check tarball integrity' do
  user 'root'
  command "echo '#{node.cassandra.tarball.md5}  #{tarball_path}' | md5sum -c"
  not_if 'which cassandra'
  only_if { node.cassandra.tarball.md5 }
end

execute "extract tarball to #{node.cassandra.installation_dir}" do
  user 'root'
  cwd  Dir.tmpdir
  command <<-EOS
    rm -rf #{node.cassandra.installation_dir}
    mkdir #{node.cassandra.installation_dir}
    tar -xf #{tarball_path} -C #{node.cassandra.installation_dir} --strip-components 1
  EOS
  creates "#{node.cassandra.installation_dir}/bin/cassandra"
end

[node.cassandra.data_root_dir, node.cassandra.log_dir, node.cassandra.run_dir].each do |dir|
  directory dir do
    owner     node.cassandra.user
    group     node.cassandra.user
    recursive true
    action    :create
  end
end

execute 'fix permissions' do
  user 'root'
  command <<-EOS
    chown -R #{node.cassandra.user}:#{node.cassandra.user} #{node.cassandra.installation_dir}
    chmod -R 755 #{node.cassandra.run_dir} #{node.cassandra.log_dir} #{node.cassandra.data_root_dir}
  EOS
end

execute "link #{node.cassandra.conf_dir}" do
  actual_conf_dir = File.join(node.cassandra.installation_dir, 'conf')
  user 'root'
  command "ln -fs #{actual_conf_dir} #{node.cassandra.conf_dir}"
  not_if { node.cassandra.conf_dir == actual_conf_dir }
end

%w(cassandra.yaml).each do |f|
  template File.join(node.cassandra.conf_dir, f) do
    source "#{f}.erb"
    owner node.cassandra.user
    group node.cassandra.user
    mode  0644
  end
end

execute "change RMI settings in cassandra-env.sh" do
  c_env_path = File.join(node.cassandra.conf_dir, 'cassandra-env.sh')
  user node.cassandra.user
  command %<sed -i -e 's/JVM_OPTS="$JVM_OPTS -Dcom.sun.management.jmxremote.authenticate=false"/&\\nJVM_OPTS="$JVM_OPTS -Djava.rmi.server.hostname=#{node.cassandra.listen_address}"/' #{c_env_path}>
  not_if "grep 'java.rmi.server.hostname=#{node.cassandra.listen_address}' #{c_env_path}"
end

execute "change logging paths in #{node.cassandra.conf_dir}/log4j-server.properties" do
  user node.cassandra.user
  command %<sed -i -e 's|log4j\.appender\.R\.File=.+/system\.log|log4j.appender.R.File=#{node.cassandra.log_dir}/system.log|' #{node.cassandra.conf_dir}/log4j-server.properties>
end

%w(cassandra cassandra-cli cassandra-shuffle cqlsh debug-cqlsh json2sstable nodetool sstable2json sstablekeys sstableloader sstablescrub).each do |f|
  file "/usr/local/bin/#{f}" do
    owner node.cassandra.user
    group node.cassandra.user
    mode 00755
    action :create
    content %<#!/bin/sh\nexec "#{node.cassandra.installation_dir}/bin/#{f}" "$@"\n>
  end
end

template "/etc/security/limits.d/#{node.cassandra.user}.conf" do
  source "cassandra-limits.conf.erb"
  owner node.cassandra.user
  mode  0644
end

template "/etc/init.d/cassandra" do
  source 'cassandra.init.erb'
  owner 'root'
  mode  0755
end

service 'cassandra' do
  supports :start => true, :stop => true, :restart => true
  action [:enable, :start]
end
