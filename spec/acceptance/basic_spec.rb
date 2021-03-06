require 'spec_helper_acceptance'

describe 'basic installation' do
  certdir = '/etc/pulpcore-certs'

  let(:pp) {
    <<-PUPPET
    if $facts['os']['release']['major'] == '7' {
      class { 'postgresql::globals':
        version              => '12',
        client_package_name  => 'rh-postgresql12-postgresql-syspaths',
        server_package_name  => 'rh-postgresql12-postgresql-server-syspaths',
        contrib_package_name => 'rh-postgresql12-postgresql-contrib-syspaths',
        service_name         => 'postgresql',
        datadir              => '/var/lib/pgsql/data',
        confdir              => '/var/lib/pgsql/data',
        bindir               => '/usr/bin',
      }
      class { 'redis::globals':
        scl => 'rh-redis5',
      }
    }

    class { 'pulpcore':
      worker_count      => 2,
      apache_https_cert => '#{certdir}/ca-cert.pem',
      apache_https_key  => '#{certdir}/ca-key.pem',
      apache_https_ca   => '#{certdir}/ca-cert.pem',
    }
    PUPPET
  }

  it_behaves_like 'a idempotent resource'

  describe service('httpd') do
    it { is_expected.to be_enabled }
    it { is_expected.to be_running }
  end

  describe service('pulpcore-api') do
    it { is_expected.to be_enabled }
    it { is_expected.to be_running }
  end

  describe service('pulpcore-content') do
    it { is_expected.to be_enabled }
    it { is_expected.to be_running }
  end

  describe service('pulpcore-resource-manager') do
    it { is_expected.to be_enabled }
    it { is_expected.to be_running }
  end

  describe service('pulpcore-worker@1') do
    it { is_expected.to be_enabled }
    it { is_expected.to be_running }
  end

  describe service('pulpcore-worker@3') do
    it { is_expected.not_to be_enabled }
    it { is_expected.not_to be_running }
  end

  describe port(80) do
    it { is_expected.to be_listening }
  end

  describe port(443) do
    it { is_expected.to be_listening }
  end

  describe curl_command("https://#{host_inventory['fqdn']}/pulp/api/v3/status/", cacert: "#{certdir}/ca-cert.pem") do
    its(:response_code) { is_expected.to eq(200) }
    its(:exit_status) { is_expected.to eq 0 }
  end

  describe command("PULP_SETTINGS=/etc/pulp/settings.py pulpcore-manager dumpdata auth.User") do
    its(:stdout) { is_expected.to match(/auth\.user/) }
    its(:exit_status) { is_expected.to eq 0 }
  end

  describe curl_command("https://#{host_inventory['fqdn']}/pulp/api/v3/", cacert: "#{certdir}/ca-cert.pem") do
    its(:response_code) { is_expected.to eq(200) }
    its(:body) { is_expected.not_to contain('artifacts_list') }
    its(:exit_status) { is_expected.to eq 0 }
  end

  describe curl_command("https://#{host_inventory['fqdn']}/pulp/api/v3/",
                        cacert: "#{certdir}/ca-cert.pem", key: "#{certdir}/client-key.pem", cert: "#{certdir}/client-cert.pem") do
    its(:response_code) { is_expected.to eq(200) }
    its(:body) { is_expected.to contain('artifacts_list') }
    its(:exit_status) { is_expected.to eq 0 }
  end
end

describe 'reducing worker count' do
  certdir = '/etc/pulpcore-certs'

  let(:pp) {
    <<-PUPPET
    if $facts['os']['release']['major'] == '7' {
      class { 'postgresql::globals':
        version              => '12',
        client_package_name  => 'rh-postgresql12-postgresql-syspaths',
        server_package_name  => 'rh-postgresql12-postgresql-server-syspaths',
        contrib_package_name => 'rh-postgresql12-postgresql-contrib-syspaths',
        service_name         => 'postgresql',
        datadir              => '/var/lib/pgsql/data',
        confdir              => '/var/lib/pgsql/data',
        bindir               => '/usr/bin',
      }
      class { 'redis::globals':
        scl => 'rh-redis5',
      }
    }

    class { 'pulpcore':
      worker_count      => 1,
      apache_https_cert => '#{certdir}/ca-cert.pem',
      apache_https_key  => '#{certdir}/ca-key.pem',
      apache_https_ca   => '#{certdir}/ca-cert.pem',
    }
    PUPPET
  }

  it_behaves_like 'a idempotent resource'

  describe service('httpd') do
    it { is_expected.to be_enabled }
    it { is_expected.to be_running }
  end

  describe service('pulpcore-api') do
    it { is_expected.to be_enabled }
    it { is_expected.to be_running }
  end

  describe service('pulpcore-content') do
    it { is_expected.to be_enabled }
    it { is_expected.to be_running }
  end

  describe service('pulpcore-resource-manager') do
    it { is_expected.to be_enabled }
    it { is_expected.to be_running }
  end

  describe service('pulpcore-worker@1') do
    it { is_expected.to be_enabled }
    it { is_expected.to be_running }
  end

  describe service('pulpcore-worker@2') do
    it { is_expected.not_to be_enabled }
    it { is_expected.not_to be_running }
  end

end
