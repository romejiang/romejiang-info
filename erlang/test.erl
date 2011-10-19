-module(test).
-export([start/0,start/1]).

start() ->
	io:format("nothing!!",[]).

start(A) ->
	io:format("is list ~p" , atom_to_list(A)),
	io:format("hello ~p",A).	
	

