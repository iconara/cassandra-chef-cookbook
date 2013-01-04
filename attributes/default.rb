default[:cassandra] = {
  :cluster_name => "Test Cluster",
  :seeds => "127.0.0.1",
  :tarball => {
    :url => "http://www.eu.apache.org/dist/cassandra/1.2.0/apache-cassandra-1.2.0-bin.tar.gz",
    :md5 => "bca870d48906172eb69ad60913934aee"
  },
  :user => "cassandra",
  :jvm  => {
    :xms => 32,
    :xmx => 512
  },
  :limits => {
    :memlock => 'unlimited',
    :nofile  => 48000
  },
  :installation_dir => "/usr/local/cassandra",
  :conf_dir         => "/etc/cassandra/",
  # commit log, data directory, saved caches and so on are all stored under the data root. MK.
  :data_root_dir    => "/var/lib/cassandra",
  :log_dir          => "/var/log/cassandra",
  :run_dir          => "/var/run/cassandra",
  :listen_address   => "localhost",
  :rpc_address      => "localhost"
}
