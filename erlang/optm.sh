#!/bin/sh
# set this to about 256/4M (16384 for 256M machine)
MAXFILES=16384
echo $MAXFILES > /proc/sys/fs/file-max
ulimit -n $MAXFILES

if [ -e /proc/sys/net/ipv4/ip_conntrack_max ]; then
        echo 65536 > /proc/sys/net/ipv4/ip_conntrack_max
fi

if [ -e /proc/sys/net/ipv4/netfilter/ip_conntrack_tcp_timeout_fin_wait ]; then
        # 30 seconds for fin, 15 for time wait
        echo 3000 > /proc/sys/net/ipv4/netfilter/ip_conntrack_tcp_timeout_fin_wait
        echo 1500 > /proc/sys/net/ipv4/netfilter/ip_conntrack_tcp_timeout_time_wait
        echo 0 > /proc/sys/net/ipv4/netfilter/ip_conntrack_tcp_log_invalid_scale
        echo 0 > /proc/sys/net/ipv4/netfilter/ip_conntrack_tcp_log_out_of_window
fi

echo 1024 60999 > /proc/sys/net/ipv4/ip_local_port_range
#echo 32768 > /proc/sys/net/ipv4/ip_queue_maxlen
echo 30 > /proc/sys/net/ipv4/tcp_fin_timeout
echo 4096 > /proc/sys/net/ipv4/tcp_max_syn_backlog
echo 262144 > /proc/sys/net/ipv4/tcp_max_tw_buckets
echo 262144 > /proc/sys/net/ipv4/tcp_max_orphans
echo 300 > /proc/sys/net/ipv4/tcp_keepalive_time
echo 1 > /proc/sys/net/ipv4/tcp_tw_recycle
echo 0 > /proc/sys/net/ipv4/tcp_timestamps
echo 0 > /proc/sys/net/ipv4/tcp_ecn
echo 0 > /proc/sys/net/ipv4/tcp_sack
echo 0 > /proc/sys/net/ipv4/tcp_dsack

# auto-tuned on 2.4
#echo 262143 > /proc/sys/net/core/rmem_max
#echo 262143 > /proc/sys/net/core/rmem_default

echo 16384 65536 524288 > /proc/sys/net/ipv4/tcp_rmem
echo 16384 349520 699040 > /proc/sys/net/ipv4/tcp_wmem

