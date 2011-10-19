-module(test_timer).

-export([start/0]).


start() ->
	erlang:start_timer(3 * 1000, self(), {ping, comeing}),
	wait(),
	ok.

wait()	->
	receive
		{timeout, _TRef, {ping, Msg}} ->
			io:format("hahah ~p", [Msg]);
		_ ->
			io:format("ooooa~~")
	end.

