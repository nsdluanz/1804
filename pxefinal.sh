#!/bin/bash
#################################################################
recho () {
      echo -e "\033[31m $1 \033[0m"
}
gecho () {
      echo -e "\033[32m $1 \033[0m"
}
becho () {
      echo -e "\033[31m "" \033[1m"
      echo -e "\033[44;37;5m "$1" \033[0m"
}
#################################################################
menu() {
clear
echo
becho "\t\t\t 一 PXE网络装机服务端环境部署脚本概要"
echo
echo -e "\t1. 请确认本机上已配好YUM客户端，否则镜像文件rhel-server-7.4-x86_64-dvd.iso将作为本机yum源,以便本机安装相关软件包."
echo -e "\t2. 本脚本为单系统装机脚本，装机镜像源为rhel-server-7.4-x86_64-dvd.iso，请确定本机已有该镜像文件."
echo -e "\t3. 请确认本机已经配好IP地址."
echo -e "\t请按任意键继续.."
read -n1 aa
}
menu
clear
###部署前自检###
becho '二 PXE本机部署环境检测'
echo "1.当前用户权限检查..."
      if [ $UID -eq 0 ];then
      gecho "当前用户为管理员权限，正常"
      else
      recho "当前用户权限不够，请重新确认"
      exit 1 
      fi
echo "2.检测本机yum是否可用..."
yum clean all &> /dev/null
num=`yum repolist 2> /dev/null| awk '/^repolist/{print $2}' | sed 's/,//g'`
if [ $num -eq 0 ];then 
   gecho "yum源错误，正在自动配置..."
echo "[dvd]
name=rhel7.4
baseurl=file:///var/www/html/rhel7.4
gpgcheck=0
enabled=1
" > /etc/yum.repos.d/rhel7.4.repo
   gecho "已自动创建yum客户端配置文件，软件包地址为本地/var/www/html/rhel7.4目录"
else 
   gecho "本机yum可用"
fi

echo "3.80端口占用检测..."
     ser1=`netstat -tulnp | grep 80 | awk -F/ '{print $2}'`
     if [ "a$ser1" == "a" ];then 
           gecho "80端口未占用"
     elif [ $ser1 == "httpd" ];then
           gecho "本机httpd服务活跃状态"
     else 
           recho "80端口被非httpd服务占用，请禁用后重新执行"
           exit 2
     fi 
echo "4.dhcp安装环境检测..."
     rpm -q dhcp
     if [ $? -eq 0 ];then 
     rpm -e dhcp  
     echo "原始dhcp软件包已被清理"
     else
     gecho "未发现dhcp干扰包"
     fi

echo
echo
sleep 1
##########################################################
becho '三 PXE本机部署环境准备'
read -p "请指出本机镜像源存放的目录的绝对路径,(如/dvd/rhel-server-7.4-x86_64-dvd.iso,则请输入/dvd): " path
[ "a$path" == "a" ] && recho "请正确指出本机镜像源存放的目录的绝对路径" && exit 1
cd $path &> /dev/null
[ $? -ne 0 ] && recho "路径错误，请正确指出本机镜像源存放的目录的绝对路径" && exit 2 
if [ ! -e rhel-server-7.4-x86_64-dvd.iso ];then
   recho "镜像rhel-server-7.4-x86_64-dvd.iso没有找到" 
   exit 3
else 
   gecho "镜像文件已匹配"
fi
##########################################################
becho '四 开始部署'
read -p "请输入本机dhcp网段的正确IP地址: " localip
read -p "请正确输入网段地址subnet: " subnet 
read -p "请正确输入网段地址的子网掩码netmask : " netmask
read -p "请输入要分配的起始地址rangfirst: " ipfirst
read -p "请输入要分配的末尾地址ranglast: " ipend
read -n1 -p "请认真检查上述参数是否正确(y/n) " real
echo
if [ "$real" == "y" ];then
  gecho "开始配置"
else
  recho "请重新执行脚本后正确输入你的参数"
  exit 4
fi
###########################################################
#创建httpd服务软件包目录
[ ! -e /var/www/html/rhel7.4 ] && mkdir -p /var/www/html/rhel7.4
#将镜像文件挂载到软件包目录
mount ${path%*/}/rhel-server-7.4-x86_64-dvd.iso /var/www/html/rhel7.4

###########################################################
#检测安装httpd,dhcp,tftp-server服务
gecho "检测安装httpd,dhcp,tftp-server服务..."
sleep 2
gecho "安装过程可能稍长，请耐心等待..."
###一.检测安装httpd,dhcp,tftp-server服务###
rpm -q httpd &> /dev/null
[ $? -ne 0 ] && yum -y install httpd &> /dev/null
rpm -q dhcp  &> /dev/null
[ $? -ne 0 ] && yum -y install dhcp &> /dev/null
rpm -q tftp-server &> /dev/null 
[ $? -ne 0 ] && yum -y install tftp-server &> /dev/null
gecho "httpd,dhcp,tftp-server软件包已全部安装完毕!"

######################################################################


###二.将菜单背景图片，驱动启动程序，菜单文件，图形模块，内核启动程序拷贝到tftp共享目录
cp /var/www/html/rhel7.4/isolinux/splash.png /var/lib/tftpboot/
cp /var/www/html/rhel7.4/isolinux/initrd.img /var/lib/tftpboot/
cp /var/www/html/rhel7.4/isolinux/isolinux.cfg /var/lib/tftpboot/
cp /var/www/html/rhel7.4/isolinux/vesamenu.c32 /var/lib/tftpboot/
cp /var/www/html/rhel7.4/isolinux/vmlinuz /var/lib/tftpboot/
###创建pxelinux.cfg目录存放default 文件
mkdir /var/lib/tftpboot/pxelinux.cfg
mv /var/lib/tftpboot/isolinux.cfg /var/lib/tftpboot/pxelinux.cfg/default  #将菜单文件更名为default
rpm -q syslinux &> /dev/null
[ $? -ne 0 ] && yum -y install syslinux > /dev/null
cp /usr/share/syslinux/pxelinux.0 /var/lib/tftpboot/
gecho "splash.png,vesamenu.c32,initrd.img,vmlinuz,pxelinux.cfg,pxelinx.0已部署完毕"


###三.修改菜单文件###
chmod 644 /var/lib/tftpboot/pxelinux.cfg/default
sed -i '65,150d' /var/lib/tftpboot/pxelinux.cfg/default #砍掉65行及以下
sed -i '11cmenu title choose your system' /var/lib/tftpboot/pxelinux.cfg/default  #11行菜单主题更名
sed -i "64cappend initrd=initrd.img ks=http://$localip/rhel7.4ks.cfg" /var/lib/tftpboot/pxelinux.cfg/default #指定驱动启动程序，指定ks文件位置
sed -i '2s/600/100/' /var/lib/tftpboot/pxelinux.cfg/default 
sed -i '62amenu default' /var/lib/tftpboot/pxelinux.cfg/default
systemctl restart tftp
systemctl enable tftp &> /dev/null
gecho "菜单文件部署完毕"

###四.修改dhcp配置文件###
cd /etc/dhcp/
#创建dhcp修改项文件
echo "subnet $subnet netmask $netmask {
range $ipfirst $ipend; 
default-lease-time 600;
max-lease-time 7200; 
next-server $localip;
filename pxelinux.0;
}" > dhcp.txt
sed -i 's/pxelinux.0/"pxelinux.0"/' dhcp.txt
#将修改项文件写入原配置文件中
sed -i '4r dhcp.txt' dhcpd.conf
rm -f dhcp.txt
systemctl restart dhcpd
systemctl enable dhcpd &> /dev/null
gecho "dhcp配置文件部署完毕"

###五.建立ks应答文件###
echo '#platform=x86, AMD64, 或 Intel EM64T
#version=DEVEL
# Install OS instead of upgrade
install
# Keyboard layouts
keyboard 'us'
# Root password
rootpw --plaintext 123
# Use network installation
url --url="http://localip/rhel7.4"
# System language
lang zh_CN
# Firewall configuration
firewall --disabled
# System authorization information
auth  --useshadow  --passalgo=sha512
# Use text mode install
text
firstboot --disable
# SELinux configuration
selinux --disabled

# Network information
network  --bootproto=dhcp --device=eth0
# Reboot after installation
reboot
# System timezone
timezone Asia/Shanghai
# System bootloader configuration
bootloader --location=mbr
# Clear the Master Boot Record
zerombr
# Partition clearing information
clearpart --all --initlabel
# Disk partitioning information
part / --fstype="xfs" --grow --size=1

%packages
@base

%end
' > /var/www/html/rhel7.4ks.cfg
sed -i "s/localip/$localip/" /var/www/html/rhel7.4ks.cfg
gecho "ks应答文件部署完毕"

systemctl restart httpd
systemctl enable httpd &> /dev/null
gecho "dhcp,httpd,tftp服务重启完毕"
becho "部署完成！！！"
