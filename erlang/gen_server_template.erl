-module(gen_server_template).  %这是我们的回调模块，也是我们实现业务逻辑的模块   
-behaviour(gen_server).  % 说明我们应用gen_server这个behaviour   
-export([start_link/0]).   
-export([alloc/0, free/1]).   
-export([init/1, handle_call/3, handle_cast/2]).  %gen_server 的导出函数   
start_link() ->  
    gen_server:start_link({local, ch3}, ch3, [], []).   
alloc() ->  
    gen_server:call(ch3, alloc).   
free(Ch) ->  
    gen_server:cast(ch3, {free, Ch}).   
init(_Args) ->  
    {ok, channels()}.   
handle_call(alloc, _From, Chs) ->  
    {Ch, Chs2} = alloc(Chs),   
    {reply, Ch, Chs2}.   
handle_cast({free, Ch}, Chs) ->  
    Chs2 = free(Ch, Chs),   
    {noreply, Chs2}.
