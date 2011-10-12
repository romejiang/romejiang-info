-module(test).
-export([start/0,start/1]).

start() ->
	io:format("nothing!!",[]).

start(A) ->
	io:format("hello ~p",[A]).	
	

