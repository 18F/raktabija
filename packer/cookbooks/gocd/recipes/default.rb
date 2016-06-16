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
  source 'cruise-config.xml.erb'
end

service 'go-agent' do
  action [:enable]
end

service 'go-server' do
  action [:enable]
end

ruby_block "add_env_to_agent" do
  block do
    file = Chef::Util::FileEdit.new("/usr/share/go-agent/agent.sh")
    file.insert_line_after_match("CWD=", "export ENVIRONMENT_NAME=\"$(curl http://169.254.169.254/latest/user-data | extract_yaml_key env_name)\"")
    file.write_file
  end
end

cookbook_file '/usr/local/bin/extract_yaml_key' do
  source 'extract_yaml_key.py'
  mode 0755
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
  user 'ubuntu'
  group 'ubuntu'
  action :run
  command 'pip3 install boto3'
end
