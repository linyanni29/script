#!/bin/bash
setenforce 0

#下载软件并安装
yum -y install lftp &>/dev/null
ping -c 3 172.25.254.250 &>/dev/null
[ $? -ne 0 ] && echo "please check network" && exit
wget ftp://172.25.254.250:/notes/project/UP200/UP200_cacti-master/pkg
yum -y install httpd php php-mysql mariadb-server mariadb
cd pkg/
yum localinstall cacti-0.8.8b-7.el7.noarch.rpm php-snmp-5.4.16-23.el7_0.3.x86_64.rpm

#配置mysql数据库
systemctl restart mariadb
mysqladmin create cacti
mysqladmin grant all on cacti.* to cactidb@'localhost' identified by '123456';
mysqladmin flush privileges;

sed -i 's/^$database_default.*/$database_default = "cacti";/' /etc/cacti/db.php
sed -i 's/^$database_hostname.*/$database_hostname = "localhost";/' /etc/cacti/db.php
sed -i 's/^$database_username.*/$database_username = "cactidb";/' /etc/cacti/db.php
sed -i 's/^$database_password.*/$database_password = "123456";/' /etc/cacti/db.php
sed -i 's/^$database_port.*/$database_port = "3306";/' /etc/cacti/db.php

#导入数据库表结构
mysql -ucactidb -p123456 cacti < /usr/share/doc/cacti-0.8.8b/cacti.sql

#配置cacti的相关参数
cp  /etc/httpd/conf.d/cacti.conf  /etc/httpd/conf.d/cacti.conf.bask
cat >  /etc/httpd/conf.d/cacti.conf << EOT
Alias /cacti    /usr/share/cacti
<Directory /usr/share/cacti/>
	<IfModule mod_authz_core.c>
		# httpd 2.4
		Require all granted 
	</IfModule>
	<IfModule !mod_authz_core.c>
		# httpd 2.2
		Order deny,allow
		Deny from all
		Allow from localhost
	</IfModule>
</Directory>
<Directory /usr/share/cacti/install>
</Directory>
<Directory /usr/share/cacti/log>
	<IfModule mod_authz_core.c>
		Require all denied
	</IfModule>
	<IfModule !mod_authz_core.c>
		Order deny,allow
		Deny from all
	</IfModule>
</Directory>
<Directory /usr/share/cacti/rra>
	<IfModule mod_authz_core.c>
		Require all denied
	</IfModule>
	<IfModule !mod_authz_core.c>
		Order deny,allow
		Deny from all
	</IfModule>
</Directory>
EOT

#配置php时区
timedatectl set-timezone Asia/Shanghai
sed -n 's/date.timezone =.*/date.timezone = Asia\/Shanghai/p' /etc/php.ini

#变更计划任务,让其每五分钟出一次图
cat > /etc/cron.d/cacti << ENT
*/5 * * * *     cacti   /usr/bin/php /usr/share/cacti/poller.php > /dev/null 2>&1
ENT

#启动服务
systemctl restart httpd
systemctl restart snmpd
systemctl enable httpd
systemctl enable snmpd
netstat -anlp |grep :80 &>/dev/null && echo "http ok"
netstat -anlp |grep :161 &>/dev/null && echo "snmp ok"







