#!/bin/bash
netstat -n|grep ^tcp|grep ESTABLISHED|awk -F '[ :]*' '{print $6}'|sort|uniq -c|sort -n

