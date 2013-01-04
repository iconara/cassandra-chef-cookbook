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


include_recipe "java"

package "jsvc" do
  action :install
end

#
# User accounts
#

user node.cassandra.user do
  comment "Cassandra Server user"
  home    node.cassandra.installation_dir
  shell   "/bin/bash"
  action  :create
end

group node.cassandra.user do
  (m = []) << node.cassandra.user
  members m
  action :create
end

version     = node.cassandra.tarball.url.scan(/apache-cassandra-([\d.]+)-bin/).flatten.first
tmp         = File.join(Dir.tmpdir, "apache-cassandra-#{version}-bin.tar.gz")
tarball_dir = File.join(Dir.tmpdir, "apache-cassandra-#{version}")

remote_file(tmp) do
  source node.cassandra.tarball.url

  not_if "which cassandra"
end

bash "extract #{tmp}, move it to #{node.cassandra.installation_dir}" do
  user "root"
  cwd  "/tmp"

  code <<-EOS
    rm -rf #{node.cassandra.installation_dir}
    tar xfz #{tmp}
    mv --force #{tarball_dir} #{node.cassandra.installation_dir}
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

%w(cassandra.yaml).each do |f|
  template File.join(node.cassandra.conf_dir, f) do
    source "#{f}.erb"
    owner node.cassandra.user
    group node.cassandra.user
    mode  0644
  end
end

%w(cassandra-env.sh).each do |f|
  source_path = File.join(node.cassandra.installation_dir, 'conf', f)
  destination_path = File.join(node.cassandra.conf_dir, f)
  execute "move #{f}" do
    user node.cassandra.user
    command "mv #{source_path} #{destination_path}"
    creates destination_path
  end
end

bash 'change heap limits in cassandra-env.sh' do
  user node.cassandra.user
  code <<-EOS
    sed -i -e's/#?MAX_HEAP_SIZE="\d+[MG]"/MAX_HEAP_SIZE="256M"/' #{node.cassandra.conf_dir}/cassandra-env.sh
    sed -i -e's/#?HEAP_NEWSIZE="\d+[MG]"/HEAP_NEWSIZE="128M"/' #{node.cassandra.conf_dir}/cassandra-env.sh
  EOS
end

%w(cassandra cassandra-cli cassandra-shuffle cqlsh debug-cqlsh json2sstable nodetool sstable2json sstablekeys sstableloader sstablescrub).each do |f|
  file "/usr/local/bin/#{f}" do
    owner node.cassandra.user
    group node.cassandra.user
    mode 00755
    action :create
    content "#!/bin/sh\n#{node.cassandra.installation_dir}/bin/#{f}"
  end
end

[
  node.cassandra.installation_dir,
  node.cassandra.log_dir,
  node.cassandra.run_dir,
  node.cassandra.data_root_dir,
  node.cassandra.conf_dir
].each do |dir|
  # Chef sets permissions only to leaf nodes, so we have to use a Bash script. MK.
  bash "chown -R #{node.cassandra.user}:#{node.cassandra.user} #{dir}" do
    user "root"
    code "mkdir -p #{dir} && chown -R #{node.cassandra.user}:#{node.cassandra.user} #{dir}"
  end
end

template "/etc/security/limits.d/#{node.cassandra.user}.conf" do
  source "cassandra-limits.conf.erb"
  owner node.cassandra.user
  mode  0644
end

ruby_block "make sure pam_limits.so is required" do
  block do
    fe = Chef::Util::FileEdit.new("/etc/pam.d/su")
    fe.search_file_replace_line(/# session    required   pam_limits.so/, "session    required   pam_limits.so")
    fe.write_file
  end
end

template "/etc/init.d/cassandra" do
  source "cassandra.init.erb"
  owner 'root'
  mode  0755
end

service "cassandra" do
  supports :start => true, :stop => true, :restart => true
  action [:enable, :start]
end
