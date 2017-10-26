#!/bin/bash
hostname='localhost'
ipaddr='172.25.20.10'
groupname='admin'

#关闭selinux和iptables
setenforce 0
iptables -F

#安装nagios
ping -c 3 172.25.254.250 &>/dev/null
[ $? -ne 0 ] && echo "please check network" && exit
rpm -q lftp
[ $? -ne 0 ] && yum -y install lftp &>/dev/null
lftp 172.25.254.250:/notes/project/UP200/UP200_nagios-master &>/dev/null
mirror pkg/
exit
cd pkg/
yum localinstall *.rpm &>/dev/null

#配置Nagios监控本机的私有服务和公共服务及主机的健康状态
cp /usr/local/nagios/etc/objects/$localhost.cfg /usr/local/nagios/etc/objects/localhost.cfg.bak
cat > /etc/nagios/objects/localhost.cfg << EOT
define host{
        use                     linux-server
        host_name               $hostmane
        alias                   nagios监控器
        address                 $ipaddr
        }
define hostgroup{
        hostgroup_name  $groupname
        alias           Linux Servers
        members         $hostmane
        }
define service{
        use                             local-service
        host_name                       $hostmane
        service_description             PING
	check_command			check_ping!100.0,20%!500.0,60%
        }
define service{
        use                             local-service
        host_name                       $hostmane
        service_description             Root Partition
	check_command			check_local_disk!20%!10%!/
        }
define service{
        use                             local-service
        host_name                       $hostmane
        service_description             Current Users
	check_command			check_local_users!20!50
        }
define service{
        use                             local-service
        host_name                       $hostmane
        service_description             Total Processes
	check_command			check_local_procs!250!400!RSZDT
        }
define service{
        use                             local-service
        host_name                       $hostmane
        service_description             Current Load
	check_command			check_local_load!5.0,4.0,3.0!10.0,6.0,4.0
        }
define service{
        use                             local-service
        host_name                       $hostmane
        service_description             Swap Usage
	check_command			check_local_swap!20!10
        }
define service{
        use                             local-service
        host_name                       $hostmane
        service_description             SSH
	check_command			check_ssh
	notifications_enabled		1
        }
define service{
        use                             local-service
        host_name                       $hostmane
        service_description             HTTP
	check_command			check_http
	notifications_enabled		1
        }
EOT

#检测语法
nagios -v /etc/nagios/nagios.cfg

#启动服务
systemctl restart nagios




