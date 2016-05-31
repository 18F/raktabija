package 'linux-generic-lts-xenial'
package 'postgresql'
#package 'terraform'
#package 'packer'

db_password = shell_out("openssl rand -base64 32").stdout.strip

concourse_binary_release = shell_out("curl https://api.github.com/repos/concourse/concourse/releases | grep browser_download_url | grep 'linux_amd64' | head -n 1 | cut -d'\"' -f4").stdout.strip

service 'concourse-web' do
  action [:stop]
  only_if { File.exist?("/lib/systemd/system/concourse-web.service") }
end

execute 'drop-atc-database' do
  command "psql -c 'DROP DATABASE IF EXISTS atc'"
  user "postgres"
  action :run
end

execute 'drop-atc-user' do
  command "psql -c 'DROP ROLE IF EXISTS atc;'"
  user "postgres"
  action :run
end

execute 'create-postgres-user' do
  command "psql -c  \"CREATE USER atc WITH PASSWORD '#{db_password}';\""
  user "postgres"
  action :run
end

execute 'create-atc-database' do
  command "createdb -O atc atc"
  user "postgres"
  action :run
end

directory '/opt/concourse/bin' do
  recursive true
  action :create
end

directory '/opt/concourse/etc' do
  recursive true
  action :create
end

execute 'create-host-key' do
  command "ssh-keygen -t rsa -f /opt/concourse/etc/host_key -N ''"
  not_if do ::File.exists?('/opt/concourse/etc/host_key') end
  action :run
end

execute 'create-worker-key' do
  command "ssh-keygen -t rsa -f /opt/concourse/etc/worker_key -N ''"
  not_if do ::File.exists?('/opt/concourse/etc/worker_key') end
  action :run
end

execute 'create-session-key' do
  command "ssh-keygen -t rsa -f /opt/concourse/etc/session_signing_key -N ''"
  not_if do ::File.exists?('/opt/concourse/etc/session_signing_key') end
  action :run
end

cookbook_file '/opt/concourse/bin/extract_yaml_key' do
  source 'extract_yaml_key.py'
  mode 0755
end

remote_file '/opt/concourse/bin/concourse' do
  source concourse_binary_release
  mode 0755
  action :create
end

template '/opt/concourse/bin/concourse-worker' do
  mode 0755
  source 'worker.erb'
end

template '/lib/systemd/system/concourse-worker.service' do
  mode 0644
  source 'worker-init.erb'
end

template '/opt/concourse/bin/concourse-web' do
  mode 0755
  source 'web.erb'
  variables({
    :db_password => db_password
  })
end

template '/lib/systemd/system/concourse-web.service' do
  mode 0644
  source 'web-init.erb'
end

service 'concourse-worker' do
  action [:enable, :start]
end

service 'concourse-web' do
  action [:enable, :start]
end
