#!/bin/bash
if [ ! $1 ]; then
	echo "加入ip到防火墙黑名单的命令"
	echo "eg ./kick-ip.sh 192.168.1.1"	
	exit;
fi
echo iptables -I INPUT -s $1 -j DROP
