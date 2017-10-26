#!/bin/bash

#配置yum源脚本

cd /etc/yum.repos.d/
find . -regex '.*\.repo$' -exec mv {} {}.back \;
cat > /etc/yum.repos.d/base.repo << EOT
[base]
baseurl=http://172.25.254.254/content/rhel6.5/x86_64/dvd
gpgcheck=0
EOT
yum clean all
yum makecache
