#!/bin/bash
if [ $1 ];then
	if [ ! -f $1.erl ]; then
		echo "file $1 not exist..."
		exit;
	fi

	echo "`date` compile & copy $1 ..."
	compile=`erlc -I /lib/ejabberd/include $1.erl -pa /lib/ejabberd/ebin`
	if [ "$compile" ]; then
		echo "$compile"
		echo compile fail!
		exit;
	fi
	cp $1.beam /lib/ejabberd/ebin/
fi

/sbin/ejabberdctl stop

while [ ! $TRY ]; do
	pid=`ps -ef | grep ejabberd@ | grep -v grep`
	if [ -z "$pid" ]; then
		/sbin/ejabberdctl start
		TRY=$?
	else
		echo waiting stop ejabberd...
		sleep 1
	fi
done
