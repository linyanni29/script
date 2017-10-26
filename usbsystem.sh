#!/bin/bash

#先判断U盘是否被挂载，如果被挂载则卸载，如果没挂就分区格式化
read -p "请输入你的U盘的名字，如：/dev/sdb :" name
newname=$(basename $name)
mname=$(/bin/mount|awk "/$newname/ {print \$1}")

if [ -n "$mname" ]
then
	for i in $mname
	do
		umount -f $i
	done
fi

dd if=/dev/zero of=$name count=1 bs=10M &> /dev/null
fdisk $name <<EOF &> /dev/null
n
p
1


a
1
w
EOF

mkfsname=$name'1'
mkfs.ext4 $mkfsname &> /dev/null

#挂载U盘
mkdir /mnt/usb -p
mount $mkfsname  /mnt/usb/

#安装文件系统
yum -y install filesystem --installroot=/mnt/usb/ &> /dev/null && echo "文件系统已安装"

#安装应用程序与bash shell
yum -y install bash coreutils findutils grep vim-enhanced rpm yum passwd net-tools util-linux lvm2 openssh-clients bind-utils --installroot=/mnt/usb/ &> /dev/null && echo "应用程序与shell已安装"

#安装内核
cp -a /boot/vmlinuz-2.6.32-431.el6.x86_64 /mnt/usb/boot/
cp -a /boot/initramfs-2.6.32-431.el6.x86_64.img /mnt/usb/boot/
cp -arv /lib/modules/2.6.32-431.el6.x86_64/ /mnt/usb/lib/modules/

#安装grub软件
rpm -ivh http://172.25.254.254/content/rhel6.5/x86_64/dvd/Packages/grub-0.97-83.el6.x86_64.rpm --root=/mnt/usb/ --nodeps --force &> /dev/null
grub-install  --root-directory=/mnt/usb/ /dev/sda --recheck &> /dev/null && echo "grub已安装"

#配置 grub.conf
id=$(blkid $mkfsname |cut -d\" -f2)
cp /boot/grub/grub.conf  /mnt/usb/boot/grub/
sed -i 's/splashimage.*/splashimage=/boot/grub/splash.xpm.gz/' /mnt/usb/boot/grub/grub.conf
sed -i 's/title.*/title My usb system from zzc/' /mnt/usb/boot/grub/grub.conf
sed -i 's/kernel.*/kernel /boot/vmlinuz-2.6.32-431.el6.x86_64 ro root=UUID=$id selinux=0/' /mnt/usb/boot/grub/grub.conf
sed -i 's/initrd.*/initrd /boot/initramfs-2.6.32-431.el6.x86_64.img/' /mnt/usb/boot/grub/grub.conf

cp /boot/grub/splash.xpm.gz /mnt/usb/boot/grub/

#完善配置文件
cp /etc/skel/.bash* /mnt/usb/root/

#配置主机名与网卡
cat > /mnt/usb/etc/sysconfig/network <<EOT
NETWORKING=yes
HOSTNAME=myusb.hugo.org
EOT

cp /etc/sysconfig/network-scripts/ifcfg-eth0 /mnt/usb/etc/sysconfig/network-scripts/

cat > /mnt/usb/etc/sysconfig/network-scripts/ifcfg-eth0 <<DEF
DEVICE="eth0"
BOOTPROTO="static"
ONBOOT="yes"
IPADDR=192.168.0.118
NETMASK=255.255.255.0
GATEWAY=192.168.0.254
DNS1=8.8.8.8
DEF

#定义fstab
uuid=$(blkid $mfksname |cut -d" " -f2)
cat > /mnt/usb/etc/fstab <<BCD
$uuid  /  ext4   defaults   0 0
proc                    /proc                   proc    defaults        0 0
sysfs                   /sys                    sysfs   defaults        0 0
tmpfs                   /dev/shm                tmpfs   defaults        0 0
devpts                  /dev/pts                devpts  gid=5,mode=620  0 0
BCD

#设置密码
sed -i 's/^root.*/root:$1$yANhV\/$51rp8k6Clhjb2aycQHBB0.:15937:0:99999:7:::/' /mnt/usb/etc/shadow

#卸载U盘
umount /mnt/usb/  && echo "U盘系统制作成功"






