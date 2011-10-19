#!/bin/bash
echo "参看网络连接数"
netstat -n | awk '/^tcp/ {++S[$NF]} END {for(a in S) print a, S[a]}'
echo "参看网络连接数"

