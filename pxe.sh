#!/usr/bin/expect
#!/bin/bash

yum install expect -y &>/dev/null

sed -i '/^'$1'/d' /root/.ssh/known_hosts
expect << EOF > /dev/null 2>&1
spawn ssh root@172.25.20.10
expect "no)?"
send "yes\r"
expect "password:"
send "uplooking\r"
expect eof
EOF

#配置servera 路由器
cat >> /etc/sysctl.conf <<END 
net.ipv4.ip_forward = 1
END
sysctl -p &>/dev/null
iptables -F
iptables -t nat -A POSTROUTING -s 192.168.0.0/24 -j SNAT --to-source 172.25.20.10

[root@serverg ~]# cat pxe.sh
#!/bin/bash
#设置serverg服务器eth1的网关
sed -i '/^'$1'/d' /root/.ssh/known_hosts
expect << EOF > /dev/null 2>&1
spawn ssh root@192.168.0.16
expect "no)?"
send "yes\r"
expect "password:"
send "uplooking\r"
expect eof
EOF

cat >> /etc/sysconfig/network-scripts/ifcfg-eth1 <<END
GATEWAY=192.168.0.10
END

#设置serverg服务器关闭桥接网卡eth0
sed -i 's/ONBOOT=.*/ONBOOT=no/g' /etc/sysconfig/network-scripts/ifcfg-eth0 

#关闭selinux与iptables
sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config
echo "/sbin/setenforce 0" >> /etc/rc.local
chmod +x /etc/rc.local &>/dev/null
source  /etc/rc.local &>/dev/null

#创建挂载目录
mkdir /yum &>/dev/null
mkdir /rhel6u5 &>/dev/null

#下载iso ，发布iso
ping -c 3 172.25.254.254 && echo "172.25.254.254已ping通"

cat >> /etc/fstab <<END
172.25.254.250:/content /mnt    nfs ro  0 0
/mnt/rhel7.1/x86_64/isos/rhel-server-7.1-x86_64-dvd.iso  /yum  iso9660 ro 0 0
/mnt/rhel6.5/x86_64/isos/rhel-server-6.5-x86_64-dvd.iso  /rhel6u5 iso9660 ro 0 0
END
mount -a &>/dev/null

#配置yum源
find /etc/yum.repos.d/ -regex '.*\.repo$' -exec mv {} {}.back \;
cat > /etc/yum.repos.d/local.repo <<EOT
[local]
baseurl=file:///yum
gpgcheck=0
EOT

yum clean all &>/dev/null
yum makecache &>/dev/null
[ $? -ne 0 ] && echo "yum配置失败" && exit 10

#搭建DHCP
yum -y install dhcp &>/dev/null
[ $? -ne 0 ] && echo "dhcp安装失败" && exit 10

\cp /usr/share/doc/dhcp-4.2.5/dhcpd.conf.example  /etc/dhcp/dhcpd.conf 

cat > /etc/dhcp/dhcpd.conf <<DNE
allow booting;
allow bootp;

option domain-name "pod20.example.com";
option domain-name-servers 172.25.254.254;
default-lease-time 600;
max-lease-time 7200;

log-facility local7;

subnet 192.168.0.0 netmask 255.255.255.0 {
  range 192.168.0.0 192.168.0.60;
  option domain-name-servers 172.25.254.254;
  option domain-name "pod0.example.com";
  option routers 192.168.0.10;
  option broadcast-address 192.168.0.255;
  default-lease-time 600;
  max-lease-time 7200;
  next-server 192.168.0.16;
  filename "pxelinux.0";
}
DNE

systemctl start dhcpd &>/dev/null
[ $? -eq 0 ] && echo "dhcp已启动"

#搭建TFTP
yum -y install tftp-server &>/dev/null
yum -y install syslinux &>/dev/null

cp /usr/share/syslinux/pxelinux.0  /var/lib/tftpboot/
mkdir /var/lib/tftpboot/pxelinux.cfg -p
touch /var/lib/tftpboot/pxelinux.cfg/default
cat > /var/lib/tftpboot/pxelinux.cfg/default <<END
default vesamenu.c32
timeout 60
display boot.msg
menu background splash.jpg
menu title Welcome to Global Learning Services Setup!

label local
        menu label Boot from ^local drive
        menu default
        localhost 0xffff

label install
        menu label Install rhel7
        kernel vmlinuz
        append initrd=initrd.img ks=http://192.168.0.16/myks.cfg

label install6
        menu label Install rhel6u5
        kernel rhel6u5/vmlinuz
        append initrd=rhel6u5/initrd.img ks=http://192.168.0.16/rhel6u5_ks.cfg
END

#生成引导相关文件
cd /yum/isolinux/
cp splash.png vesamenu.c32 vmlinuz initrd.img /var/lib/tftpboot/
mkdir  -p /var/lib/tftpboot/rhel6u5
cd /rhel6u5/isolinux/
cp vmlinuz initrd.img /var/lib/tftpboot/rhel6u5/

sed -i 's/disable.*/disable       = no/g' /etc/xinetd.d/tftp

systemctl restart xinetd &>/dev/null
[ $? -eq 0 ] && echo "tftp搭建成功"

#安装httpd服务 发布ks与iso镜像
yum -y install httpd &>/dev/null
ln -s /yum/ /var/www/html/rhel7u1 &>/dev/null
ln -s /rhel6u5/ /var/www/html/rhel6u5 &>/dev/null

#生成rhel7.1ks文件

cat > /var/www/html/myks.cfg <<ABC
#version=RHEL7
# System authorization information
auth --enableshadow --passalgo=sha512
# Reboot after installation 
reboot
# Use network installation
url --url="http://192.168.0.16/rhel7u1/"
# Use graphical install
#graphical 
text
# Firewall configuration
firewall --enabled --service=ssh
firstboot --disable 
ignoredisk --only-use=vda
# Keyboard layouts
# old format: keyboard us
# new format:
keyboard --vckeymap=us --xlayouts='us'
# System language 
lang en_US.UTF-8
# Network information
network  --bootproto=dhcp
network  --hostname=localhost.localdomain
#repo --name="Server-ResilientStorage" --baseurl=http://download.eng.bos.redhat.com/rel-eng/latest-RHEL-7/compose/Server/x86_64/os//addons/ResilientStorage
# Root password
rootpw --iscrypted nope 
# SELinux configuration
selinux --disabled
# System services
services --disabled="kdump,rhsmcertd" --enabled="network,sshd,rsyslog,ovirt-guest-agent,chronyd"
# System timezone
timezone Asia/Shanghai --isUtc
# System bootloader configuration
bootloader --append="console=tty0 crashkernel=auto" --location=mbr --timeout=1 --boot-drive=vda 
# 设置boot loader安装选项 --append指定内核参数 --location 设定引导记录的位置
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all --initlabel
# Disk partitioning information
part / --fstype="xfs" --ondisk=vda --size=6144
%post
echo "redhat" | passwd --stdin root
useradd carol
echo "redhat" | passwd --stdin carol
# workaround anaconda requirements
%end

%packages
@core
%end
ABC

#生成rhel6.5ks文件
cat > /var/www/html/rhel6u5_ks.cfg <<BCD
#platform=x86, AMD64, or Intel EM64T
#version=DEVEL
# Firewall configuration
firewall --disabled
# Install OS instead of upgrade
install
# Use network installation
url --url="http://192.168.0.16/rhel6u5"
# Root password
rootpw --plaintext redhat
# System authorization information
auth  --useshadow  --passalgo=sha512
# Use text mode install
text
firstboot --disable
# System keyboard
keyboard us
# System language
lang en_US
# SELinux configuration
selinux --disabled
# Installation logging level
logging --level=info
# Reboot after installation
reboot
# System timezone
timezone --isUtc Asia/Shanghai
# Network information
network  --bootproto=dhcp --device=eth0 --onboot=on
# System bootloader configuration
bootloader --location=mbr
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all --initlabel 
# Disk partitioning information
part /boot --fstype="ext4" --size=200
part / --fstype="ext4" --size=9000
part swap --fstype="swap" --size=1024

%pre
clearpart --all
part /boot --fstype ext4 --size=100
part pv.100000 --size=10000
part swap --size=512
volgroup vg --pesize=32768 pv.100000
logvol /home --fstype ext4 --name=lv_home --vgname=vg --size=480
logvol / --fstype ext4 --name=lv_root --vgname=vg --size=8192
%end


%post
touch /tmp/abc
%end

%packages
@base
@chinese-support
tigervnc
openssh-clients

%end
BCD

systemctl restart httpd &>/dev/null
systemctl enable httpd &>/dev/null
systemctl restart dhcpd &>/dev/null
systemctl enable dhcpd &>/dev/null
systemctl restart xinetd &>/dev/null
systemctl enable xinetd &>/dev/null

wget  http://127.0.0.1/rhel6u5/media.repo &>/dev/null  &&  echo "发布成功"


