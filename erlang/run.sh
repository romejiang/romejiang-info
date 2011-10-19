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
	erl -noshell -s $1 start
fi

