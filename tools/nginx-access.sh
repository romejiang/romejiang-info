#!/bin/bash
echo -n '比较耗费资源，平时最好不要用，你确认要用吗？(y or n)'
read confim

if [ $confim == "y" ]; then
	awk '{print $7}' /web/server/nginx/logs/access.log|sort |uniq -c |sort -n
fi
