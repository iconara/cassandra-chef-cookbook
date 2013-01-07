default[:cassandra] = {
  :cluster_name => 'Test Cluster',
  :tarball => {
    :url => 'http://www.eu.apache.org/dist/cassandra/1.2.0/apache-cassandra-1.2.0-bin.tar.gz',
    :md5 => '94b7ac630034d8eb6bc9febbefb2bd3d'
  },
  :user => 'cassandra',
  :installation_dir => '/usr/local/cassandra',
  :conf_dir         => '/etc/cassandra',
  # commit log, data directory, saved caches and so on are all stored under the data root. MK.
  :data_root_dir    => '/var/lib/cassandra',
  :log_dir          => '/var/log/cassandra',
  :run_dir          => '/var/run/cassandra',
  # listen_address must be set to something real if you want nodes in a cluster to talk. TH
  :listen_address   => 'localhost',
  :rpc_address      => '0.0.0.0',
  :seeds            => '127.0.0.1',
  :limits => {
    :memlock => 'unlimited',
    :nofile  => 48000
  },
}
