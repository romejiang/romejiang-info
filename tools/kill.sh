#!/bin/bash
echo "结束进程的命令，eg: kill.sh nginx"
kill -9 `ps -ef|grep $1|grep -v grep|awk '{print $2}'`
