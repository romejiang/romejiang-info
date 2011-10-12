-module(stress_test).  
  
-export([start/0, tests/1]).  
  
start() ->  
    tests(12345).  
  
tests(Port) ->  
    io:format("starting~n"),  
    spawn(fun() -> test(Port) end),  
    spawn(fun() -> test(Port) end),  
    spawn(fun() -> test(Port) end),  
    spawn(fun() -> test(Port) end).  
  
test(Port) ->  
     case gen_tcp:connect("192.168.1.58", Port, [binary,{packet, 0}]) of  
    {ok, _} ->  
            test(Port);  
    _ ->  
        test(Port)  
    end.
