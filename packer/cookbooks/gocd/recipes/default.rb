apt_update "update" do
  action :update
end

package 'linux-generic-lts-xenial'
package 'openjdk-8-jdk-headless'
package 'unzip'
package 'apache2-utils'
package 'python3-pip'
package 'awscli'

db_password = shell_out("tr -cd '[:alnum:]' < /dev/urandom | fold -w30 | head -n1").stdout.strip
terraform_binary_release = shell_out("curl https://www.terraform.io/downloads.html | grep 'linux_amd64' | head -n 1 | cut -d'\"' -f2").stdout.strip
packer_binary_release = shell_out("curl https://www.packer.io/downloads.html | grep 'linux_amd64' | head -n 1 | cut -d'\"' -f2").stdout.strip

apt_repository "gocd" do
  uri "https://download.go.cd"
  distribution "/"
  key "https://download.go.cd/GOCD-GPG-KEY.asc"
end

package 'go-server'
package 'go-agent'

template '/etc/go/cruise-config.xml' do
  mode 0600
  owner 'go'
  source 'cruise-config.xml.erb'
end

execute 'configure_env_name' do
  command 'cat /home/ubuntu/env >> /etc/default/go-agent'
end

service 'go-agent' do
  action [:enable, :start]
end

service 'go-server' do
  action [:enable, :start]
end

remote_file '/home/ubuntu/packer.zip' do
  source packer_binary_release
  mode 0755
  action :create
end

remote_file '/home/ubuntu/terraform.zip' do
  source terraform_binary_release
  mode 0755
  action :create
end

execute 'unzip_packer' do
  user 'root'
  group 'root'
  cwd '/home/ubuntu'
  action :run
  creates '/usr/local/bin/packer'
  command 'unzip -d /usr/local/bin packer.zip' 
end

execute 'unzip_terraform' do
  user 'root'
  group 'root'
  cwd '/home/ubuntu'
  action :run
  command 'unzip -d /usr/local/bin terraform.zip' 
  creates '/usr/local/bin/terraform'
end

execute 'boto3' do
  user 'go'
  group 'go'
  action :run
  command 'pip3 install boto3'
end

#Delete IP & hostname before creating AMI
ruby_block "delete_ami_hostname" do
  block do
    file = Chef::Util::FileEdit.new("/etc/hosts")
    file.search_file_delete_line("autogenerated")
    file.write_file
  end
end
