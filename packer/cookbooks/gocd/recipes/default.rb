#package 'linux-generic-lts-xenial'
package 'openjdk-8-jdk-headless'
package 'unzip'

db_password = shell_out("tr -cd '[:alnum:]' < /dev/urandom | fold -w30 | head -n1").stdout.strip
terraform_binary_release = shell_out("curl https://www.terraform.io/downloads.html | grep 'linux_amd64' | head -n 1 | cut -d'\"' -f2").stdout.strip
packer_binary_release = shell_out("curl https://www.packer.io/downloads.html | grep 'linux_amd64' | head -n 1 | cut -d'\"' -f2").stdout.strip

apt_repository "gocd" do
  uri "https://download.go.cd"
  distribution "/"
  key "https://download.go.cd/GOCD-GPG-KEY.asc"
end

package ["go-server", "go-agent"] do
  action :install
end

directory '/opt/packer/bin' do
  recursive true
  action :create
end

directory '/opt/terraform/bin' do
  recursive true
  action :create
end

directory '/opt/gocd/bin' do
  recursive true
  action :create
end

cookbook_file '/opt/gocd/bin/extract_yaml_key' do
  source 'extract_yaml_key.py'
  mode 0755
end

remote_file '/opt/packer/packer.zip' do
  source packer_binary_release
  mode 0755
  action :create
end

remote_file '/opt/terraform/terraform.zip' do
  source terraform_binary_release
  mode 0755
  action :create
end

execute 'unzip_packer' do
  user 'root'
  group 'root'
  cwd '/opt/packer'
  action :run
  creates '/opt/packer/bin/packer'
  command 'unzip -d bin packer.zip' 
end

execute 'unzip_terraform' do
  user 'root'
  group 'root'
  cwd '/opt/terraform'
  action :run
  command 'unzip -d bin terraform.zip' 
  creates '/opt/terraform/bin/terraform'
end

service 'go-server' do
  action [:enable, :start]
end

service 'go-agent' do
  action [:enable, :start]
end
