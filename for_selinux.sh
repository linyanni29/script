#!/bin/bash
for i in {21..23}
do
ssh 172.25.20.$i "sed -i 's/^SELINUX=.*/SELINUX=disabled/' /etc/selinux/config"
ssh 172.25.20.$i "setenforce 0"
ssh 172.25.20.$i "iptables -F"
done
