#!/bin/bash
##############################
#agent-->172.25.20.12
#server-->172.15.20.13
#web--->172.25.20.14
#database-->172.25.20.15
##############################
#推送密钥对，同步时间，关闭selinux
for i in {12..15}; do
ssh 172.25.20.$i " timedatectl set-timezone Asia/Shanghai;ntpdate -u 172.25.254.254;setenforce 0"
done

#在server端源码安装zabbix
rpm -q lftp &>/dev/null
[ $? -ne 0 ] && yum -y install lftp &>/dev/null
lftp://172.25.254.250:/notes/project/software/zabbix/zabbix3.2 << EOT &>/dev/null
mirror zabbix3.2/
exit
EOT
tar xf zabbix-3.2.7.tar.gz -C /usr/local/src/ &>/dev/null
yum install gcc gcc-c++ mariadb-devel libxml2-devel net-snmp-devel libcurl-devel -y

cd /usr/local/src/zabbix-3.2.7/
/usr/local/src/zabbix-3.2.7/configure --prefix=/usr/local/zabbix --enable-server --with-mysql --with-net-snmp --with-libcurl --with-libxml2 --enable-agent --enable-ipv6 &>/dev/null
make && make install &>/dev/null

useradd zabbix
sed -i 's/.*DBHost=.*/DBHost=172.25.20.15/' /usr/local/zabbix/etc/zabbix_server.conf
sed -i 's/.*DBName=.*/DBName=zabbix/' /usr/local/zabbix/etc/zabbix_server.conf
sed -i 's/.*DBUser=.*/DBUser=zabbix/' /usr/local/zabbix/etc/zabbix_server.conf
sed -i 's/.*DBPassword=.*/DBPassword=uplooking/' /usr/local/zabbix/etc/zabbix_server.conf

#拷贝表结构到database端
cd /usr/local/src/zabbix-3.2.7/database/mysql/
scp -r * 172.25.20.15:/root/

#在Database端的安装配置数据库
ssh root@172.25.20.15 "yum -y install mariadb-server mariadb;systemctl start mariadb" &>/dev/null

ssh root@172.25.20.15 "mysqladmin drop test;mysqladmin create zabbix"
ssh root@172.25.20.15 "mysql zabbix < /root/schema.sql;mysql zabbix < /root/images.sql;mysql zabbix < /root/data.sql"
mysqladmin grant all on zabbix.* to zabbix@'%' identified by 'uplooking'
mysqladmin flush-privileges

#配置web端
rsync -avzR /root/zabbix3.2 172.25.20.14:/ &>/dev/null
ssh root@172.25.20.14 "yum -y install httpd php php-mysql"
ssh root@172.25.20.14 "cd /root/zabbix3.2 ;yum localinstall zabbix-web-3.2.7-1.el7.noarch.rpm zabbix-web-mysql-3.2.7-1.el7.noarch.rpm"
ssh root@172.25.20.14 "sed -i 's/.*php_value date.timezone.*/php_value date.timezone Asia\/Shanghai/' /etc/httpd/conf.d/zabbix.conf"

#server端启动服务
/usr/local/zabbix/sbin/./zabbix_server
netstat -tnlp |grep zabbix &>/dev/null && [ $? -eq 0 ] && echo "zabbix服务端 ok"

#web端启动服务
ssh root@172.25.20.14 "systemctl restart httpd;systemctl enable httpd"

#配置agent端
rsync -avzR /root/zabbix3.2 172.25.20.12:/ &>/dev/nul
ssh root@172.25.20.12 "cd /root/zabbix3.2;pm -ivh zabbix-agent-3.2.7-1.el7.x86_64.rpm; yum -y install net-snmp net-snmp-utils"

ssh root@172.25.20.12 "sed -i 's/Server=.*/Server=172.25.20.13/' /etc/zabbix/zabbix_agentd.conf;sed -i 's/ServerActive=.*/ServerActive=172.25.20.13/' /etc/zabbix/zabbix_agentd.conf;sed -i 's/Hostname=.*/Hostname=serverc.pod20.example.com/' /etc/zabbix/zabbix_agentd.conf;sed -i 's/.*UnsafeUserParameters=.*/UnsafeUserParameters=1/' /etc/zabbix/zabbix_agentd.conf"
ssh root@172.25.20.12 "systemctl start zabbix-agent;systemctl enable zabbix-agent"






