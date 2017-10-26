#!/bin/bash

#准备环境：
#servera:192.168.0.10
#serverb:192.168.0.11

#更改主机名，关闭seliunx，关闭eth0网卡，设置网关
hostnamectl set-hostname cobbler
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
setenforce 0
sed -i 's/ONBOOT=yes/ONBOOT=no/' /etc/sysconfig/network-scripts/ifcfg-eth0
sed -i '$a GATEWAY=192.168.0.10' /etc/sysconfig/network-scripts/ifcfg-eth1
systemctl restart network &>/dev/null

#下载软件，并安装
#ping -c 4 172.25.254.254 && >/dev/null
[ $? -ne 0 ] && echo "网络有问题" && exit
wget -r ftp://172.25.254.250/notes/project/software/cobbler_rhel7/ &>/dev/null
mkdir /root/cobbler -p
mv 172.25.254.250/notes/project/software/cobbler_rhel7/ /root/cobbler
cd /root/cobbler/
rpm -ivh python2-simplejson-3.10.0-1.el7.x86_64.rpm &>/dev/null
rpm -ivh python-django-1.6.11.6-1.el7.noarch.rpm python-django-bash-completion-1.6.11.6-1.el7.noarch.rpm &>/dev/null
yum localinstall cobbler-2.8.1-2.el7.x86_64.rpm cobbler-web-2.8.1-2.el7.noarch.rpm &>/dev/null && echo "cobbler安装成功"

#启动服务
systemctl start httpd &>/dev/null
systemctl enable httpd &>/dev/null
netstat -tunpl |grep :80  && echo "httpd 已启动"
systemctl start cobblerd &>/dev/null
systemctl enable cobblerd &>/dev/null
netstat -tunpl |grep :873  && echo "cobblerd 已启动"

#cobbler check 检测解决
sed -i 's/^server:.*/server: 192.168.0.11/' /etc/cobbler/settings
sed -i 's/^next_server:.*/next_server: 192.168.0.11/' /etc/cobbler/settings
sed -i 's/disable.*/disable=no/' /etc/xinetd.d/tftp
yum -y install syslinux &>/dev/null
systemctl start rsyncd &>/dev/null
systemctl enable rsyncd &>/dev/null
netstat -tnlp |grep :888 &> /dev/null && echo "rsync OK"
yum -y install pykickstart &>/dev/null && echo "pykickstart安装成功"

#设置root密码
#openssl passwd -1 -salt 'random-phrase-here' 'redhat' &>/dev/null
sed -i 's/ default_password_crypted:/default_password_crypted: "$1$random-p$MvGDzDfse5HkTwXB2OLNb."/' /etc/cobbler/settings

#安装fence设备
yum -y install fence-agents &>/dev/null && echo "fence-agents安装成功"

#导入镜像
mkdir /yum &>/dev/null
mount -t nfs 172.25.254.250:/content /mnt/ &>/dev/null
mount -o loop /mnt/rhel7.2/x86_64/isos/rhel-server-7.2-x86_64-dvd.iso /yum/ &>/dev/null
cobbler import --path=/yum/ --name=rhel-server-7.2-base --arch=x86_64

#安装dhcp并修改配置文件
yum -y install dhcp &>/dev/null && echo "dhcp安装成功"

sed -i 's/192.168.1/192.168.0/g' /etc/cobbler/dhcp.template
sed -i 's/option routers.*/option routers             192.168.0.10;/' /etc/cobbler/dhcp.template
sed -i 's/option domain-name-servers 192.168.0.1;/option domain-name-servers 172.25.254.254;/' /etc/cobbler/dhcp.template 

sed -i 's/manage_dhcp:/manage_dhcp: 1/' /etc/cobbler/settings

#重启服务
systemctl restart httpd &>/dev/null
systemctl restart cobblerd &>/dev/null && echo "cobbler重启成功,进入数据通步cobbler sync"

#同步数据
#执行生成密钥对 ssh-keygen (默认回车)
#推送公钥root@localhost 
# --> ssh-copy-id root@localhost
yum install expect -y &>/dev/null
sed -i '/^localhost/d' /root/.ssh/known_hosts
expect << EOF > /dev/null 2>&1
spawn ssh-keygen
expect "id_rsa):"
send "\r"
expect "rase):"
send "\r"
expect "again:"
send "\r"
spawn ssh-copy-id root@localhost
expect "no)?"
send "yes\r"
expect "password:"
send "uplooking\r"
expect eof
EOF

ssh root@localhost "cobbler sync"

#cobbler sync &>/dev/null

systemctl restart xinetd &>/dev/null
systemctl enable xinetd &>/dev/null && echo "脚本执行成功，可进行系统安装"







