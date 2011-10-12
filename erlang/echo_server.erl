-module(echo_server).  
-export([start/0,stop/0]).  
  
-define(LISTEN_PORT,12345).     % 开放端口  
-define(MAX_CONN, 5000).        % 最大连接数  
  
start() ->  
    process_flag(trap_exit, true), % 设置退出陷阱  
	tcp_server:start_raw_server(?LISTEN_PORT,  
                fun(Socket) -> socket_handler(Socket,self()) end,  
                ?MAX_CONN,   
                0).  
  
%% 处理数据  
socket_handler(Socket,Controller) ->  
    receive  
        {tcp, Socket, Bin} ->  
            gen_tcp:send(Socket, Bin); % echo  
        {tcp_closed, Socket} ->  
            ok;  
        _ ->  
            socket_handler(Socket,Controller)  
    end.  
  
stop() ->  
    tcp_server:stop(?LISTEN_PORT).
