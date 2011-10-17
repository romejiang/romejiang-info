#!/bin/bash
echo "参看tcp连接ip统计，帮助找到ip访问过多的情况"
netstat -n|grep ^tcp |awk -F '[ :]*' '{print $6}'|sort|uniq -c|sort -n
echo "参看tcp连接ip统计，帮助找到ip访问过多的情况"

