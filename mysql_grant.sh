#!/bin/sh
#
# Mysql数据库用户权限管理
#
. /etc/rc.d/init.d/functions
#定义全局变量mysql
MYSQLCMD="/usr/local/mysql/bin/mysql"
#声明添加用户授权函数
function add_auth()
{
read -p 'Port: ' add_auth[0]
read -p 'DB [db.* | db.t1]: ' add_auth[1]
read -p 'Permisions [SELECT,UPDATE...]: ' add_auth[2]
read -p "Authorized to host's IP: " add_auth[3]
read -p 'Username: ' add_auth[4]
read -s -p 'Password: ' add_auth[5]#隐藏密码回显
#定义局部参数变量
PORT=${add_auth[0]} #数据库端口
DB=${add_auth[1]}#需要授权的数据库或表
LIMITS=${add_auth[2]}#权限类型
IP=${add_auth[3]}#授权远程主机IP登陆
USERNAME=${add_auth[4]}#连接用户名
PASSWD=${add_auth[5]}#密码
SOCKT="/tmp/mysql${PORT}.sock"#数据库连接SOCK文件
#授权
$MYSQLCMD -S $SOCKT -e "grant $LIMITS on ${DB} to \"${USERNAME}\"@\"${IP}\" identified by \"$PASSWD\";" && ret1=0
#刷新授权表
$MYSQLCMD -S $SOCKT -e "FLUSH PRIVILEGES;" && ret2=0
if [ $ret1 = 0 ] && [ $ret2 = 0 ]
then
echo -e "\n\033[32;49;1m Successfully Authorized for user $USER. \033[39;49;0m"
fi
}
#声明撤销用户权限函数drop_user()
function drop_user()
{
read -p 'Port: ' revoke_auth[0]
read -p 'Need to revoke username: ' revoke_auth[1]
read -p 'Revoke Host: ' revoke_auth[2]
PORT=${revoke_auth[0]}
USER=${revoke_auth[1]}
HOST=${revoke_auth[2]}
SOCKT="/tmp/mysql${PORT}.sock"
$MYSQLCMD -S $SOCKT -e "drop user ${USER}@\"${HOST}\";" && ret1=0
$MYSQLCMD -S $SOCKT -e "FLUSH PRIVILEGES;" && ret2=0
if [ $ret1 = 0 ] && [ $ret2 = 0 ]
then
echo -e "\n\033[32;49;1m Successfully to drop user $USER. \033[39;49;0m"
fi
}
#读取用户输入，判断添加用户授权OR撤销用户
read -p 'Add or revoke the Authorization? [ add | drop ] ' n
case "$n" in
'add')
add_auth
;;
'drop')
drop_user
;;
*)
echo "Select: add or drop"
esac
