%%%----------------------------------------------------------------------
%%% File    : mod_ping.erl
%%% Author  : Brian Cully <bjc@kublai.com>
%%% Purpose : Support XEP-0199 XMPP Ping and periodic keepalives
%%% Created : 11 Jul 2009 by Brian Cully <bjc@kublai.com>
%%%
%%%
%%% ejabberd, Copyright (C) 2002-2011   ProcessOne
%%%
%%% This program is free software; you can redistribute it and/or
%%% modify it under the terms of the GNU General Public License as
%%% published by the Free Software Foundation; either version 2 of the
%%% License, or (at your option) any later version.
%%%
%%% This program is distributed in the hope that it will be useful,
%%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
%%% General Public License for more details.
%%%
%%% You should have received a copy of the GNU General Public License
%%% along with this program; if not, write to the Free Software
%%% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA
%%% 02111-1307 USA
%%%
%%%----------------------------------------------------------------------

-module(mod_message_ping).
-author('romejiang@gmail.com').
%% 简单状态机 和 默认的服务器接口
-behavior(gen_mod).
-behavior(gen_server).

-include("ejabberd.hrl").
-include("jlib.hrl").

-define(SUPERVISOR, ejabberd_sup). % 订阅的事件名
-define(NS_PING, "urn:xmpp:ping"). % ping 的命名空间
-define(DEFAULT_SEND_PINGS, false). % bool()
-define(DEFAULT_PING_INTERVAL, 60). % seconds

%% 定义一个数据集合，用来存储什么玩意
-define(ETS_TABLE,history_message).
-define(IQ_TIMEOUT, 32). %% this is second

%% API
-export([start_link/2, start_ping/2, stop_ping/2]).

%% gen_mod callbacks
-export([start/2, stop/1]).

%% gen_server callbacks
-export([init/1, terminate/2, handle_call/3, handle_cast/2,
         handle_info/2, code_change/3]).

%% Hook callbacks
-export([iq_ping/3, user_online/3, user_offline/3, user_send/3]).

%% ets 数据结构
-record(state, {host = "",
                send_pings = ?DEFAULT_SEND_PINGS,
                ping_interval = ?DEFAULT_PING_INTERVAL,
				timeout_action = none}).

%%====================================================================
%% API
%%====================================================================
%% register myself 
start_link(Host, Opts) ->
    Proc = gen_mod:get_module_proc(Host, ?MODULE),
    gen_server:start_link({local, Proc}, ?MODULE, [Host, Opts], []).

%% send async info to handle_cast stop_ping and start_ping
start_ping(Host, JID) ->
    Proc = gen_mod:get_module_proc(Host, ?MODULE),
    gen_server:cast(Proc, {start_ping, JID}).

stop_ping(Host, JID) ->
    Proc = gen_mod:get_module_proc(Host, ?MODULE),
    gen_server:cast(Proc, {stop_ping, JID}).

%%====================================================================
%% gen_mod callbacks
%%====================================================================
%% gen_mod ejabberd is behavior.
%% register to supervisor
start(Host, Opts) ->
    Proc = gen_mod:get_module_proc(Host, ?MODULE),
    PingSpec = {Proc, {?MODULE, start_link, [Host, Opts]},
                transient, 2000, worker, [?MODULE]},
    supervisor:start_child(?SUPERVISOR, PingSpec).

stop(Host) ->
    Proc = gen_mod:get_module_proc(Host, ?MODULE),
    gen_server:call(Proc, stop),
    supervisor:delete_child(?SUPERVISOR, Proc).

%%====================================================================
%% gen_server callbacks
%%====================================================================
init([Host, Opts]) ->
	%% init config ...
    SendPings = gen_mod:get_opt(send_pings, Opts, ?DEFAULT_SEND_PINGS),
    PingInterval = gen_mod:get_opt(ping_interval, Opts, ?DEFAULT_PING_INTERVAL),
    TimeoutAction = gen_mod:get_opt(timeout_action, Opts, none),
    %%IQDisc = gen_mod:get_opt(iqdisc, Opts, no_queue),
	%% register namespace etc: urn:xmpp:ping
    mod_disco:register_feature(Host, ?NS_PING),
	%%  important %%%%%%%%%%%%%%%%% 
	%% register iq callback funciont iq_ping
    %%gen_iq_handler:add_iq_handler(ejabberd_sm, Host, ?NS_PING,
    %%                              ?MODULE, iq_ping, IQDisc),
    %%gen_iq_handler:add_iq_handler(ejabberd_local, Host, ?NS_PING,
    %%                              ?MODULE, iq_ping, IQDisc),
	%% register callback funciton online, offline,user_send
    case SendPings of
        true ->
            ejabberd_hooks:add(sm_register_connection_hook, Host,
                               ?MODULE, user_online, 100),
            ejabberd_hooks:add(sm_remove_connection_hook, Host,
                               ?MODULE, user_offline, 100),
			ejabberd_hooks:add(user_send_packet, Host,
							   ?MODULE, user_send, 100);
        _ ->
            ok
    end,
	ets:new(?ETS_TABLE , [ordered_set, public, named_table, {write_concurrency, true}]),
    {ok, #state{host = Host,
                send_pings = SendPings,
                ping_interval = PingInterval,
				timeout_action = TimeoutAction}}.

terminate(_Reason, #state{host = Host}) ->
    ejabberd_hooks:delete(sm_remove_connection_hook, Host,
			  ?MODULE, user_offline, 100),
    ejabberd_hooks:delete(sm_register_connection_hook, Host,
			  ?MODULE, user_online, 100),
    ejabberd_hooks:delete(user_send_packet, Host,
			  ?MODULE, user_send, 100),
	%%gen_iq_handler:remove_iq_handler(ejabberd_local, Host, ?NS_PING),
    %%gen_iq_handler:remove_iq_handler(ejabberd_sm, Host, ?NS_PING),
    mod_disco:unregister_feature(Host, ?NS_PING).

handle_call(stop, _From, State) ->
    {stop, normal, ok, State};
handle_call(_Req, _From, State) ->
    {reply, {error, badarg}, State}.
%% manager dict add del 
handle_cast({start_ping, JID}, State) ->
    IQ = #iq{type = get,
		sub_el = [{xmlelement, "ping", [{"xmlns", ?NS_PING}], []}]},
    Pid = self(),
    F = fun(Response) ->
        gen_server:cast(Pid, {iq_pong, JID, Response})
    end,
    From = jlib:make_jid("", State#state.host, ""),
    ?INFO_MSG("send ping message to ~p", [IQ]),
    ejabberd_local:route_iq(From, JID, IQ, F),
    {noreply, State};
handle_cast({stop_ping, _JID}, State) ->
    {noreply, State};
%% Info query timeout
handle_cast({iq_pong, JID, timeout}, State) ->
    ejabberd_hooks:run(user_ping_timeout, State#state.host, [JID]),
	?INFO_MSG("IQ timeout kick user ~p", [JID]),
    case State#state.timeout_action of
	kill ->
	    #jid{user = User, server = Server, resource = Resource} = JID,
	    case ejabberd_sm:get_session_pid(User, Server, Resource) of
		Pid when is_pid(Pid) ->
		    ejabberd_c2s:stop(Pid),
			resend_history_message(JID);
		_ ->
		    ok
	    end;
	_ ->
	    ok
    end,
    {noreply, State};
%% Received a reply
handle_cast({iq_pong, JID, #iq{type = Type}	= IQquery}, State) ->
	?INFO_MSG("IQ response info = ~p~p",[Type , IQquery] ),
	case Type of
		"error" ->
			gen_server:cast(self(), {iq_pong, JID, timeout});
		_ ->
			clean_history_message(JID)
	end,
	{noreply, State};
handle_cast(_Msg, State) ->
    {noreply, State}.
handle_info(_Info, State) ->
    {noreply, State}.
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%====================================================================
%% Hook callbacks
%%====================================================================
iq_ping(_From, _To, #iq{type = Type, sub_el = SubEl} = IQ) ->
	?INFO_MSG("iq ping callback ~p", [SubEl]),
	case {Type, SubEl} of
        {get, {xmlelement, "ping", _, _}} ->
            IQ#iq{type = result, sub_el = []};
        _ ->
            IQ#iq{type = error, sub_el = [SubEl, ?ERR_FEATURE_NOT_IMPLEMENTED]}
    end.

user_online(_SID, _JID, _Info) ->
    %%start_ping(JID#jid.lserver, JID).
	ok.

user_offline(_SID, JID, _Info) ->
    stop_ping(JID#jid.lserver, JID).

user_send(From , JID, {xmlelement, "message", _, _} = Packet) ->
	?INFO_MSG("user_send_packet send source = ~p",[Packet]),
    case xml:get_subtag_cdata(Packet, "body") of
		"" ->
			ok;
		_Body ->
			%% check JID online #########################################
			case xml:get_tag_attr_s("type", Packet) of
				"error" ->
					?ERROR_MSG("Received error message~n~p -> ~p~n~p", [From, JID, Packet]);
				_ ->
					ets:insert(?ETS_TABLE ,{erlang:now(), JID, From, Packet}),
					start_ping(JID#jid.lserver, JID)
			end
    end;
user_send(_JID, _From, _Packet) ->
	?INFO_MSG("user_send_packet stop!!",[]),
	ok.
%%====================================================================
%% Internal functions
%%====================================================================
clean_history_message(JID) ->
	Es = ets:select(?ETS_TABLE,[{{'_',JID,'_','_'},[],['$_']}]),
	lists:foreach(fun({ID, _JID, _From, Packet}) ->
			TimeDiff = time_diff(ID , erlang:now()),
			?INFO_MSG("time diff ~p ",[TimeDiff]),
			if
				TimeDiff > ?IQ_TIMEOUT -> ets:delete(?ETS_TABLE, ID);
		   		true -> ?INFO_MSG("~p ~p = ~p ~n", [time_to_second(ID) , TimeDiff , Packet])
			end
		end, Es).
resend_history_message(JID) ->
    Es = ets:select(?ETS_TABLE,[{{'_',JID,'_','_'},[],['$_']}]),
    lists:foreach(fun({ID, _JID, From, Packet}) ->
            TimeDiff = time_diff(ID , erlang:now()),
            if
                TimeDiff > ?IQ_TIMEOUT -> ets:delete(?ETS_TABLE, ID);
                true -> 
					ejabberd_router:route(From, JID, Packet)
            end
        end, Es).
time_diff({A1,A2,A3}, {B1,B2,B3}) -> 
    (B1 - A1) * 1000000 + (B2 - A2) + (B3 - A3) / 1000000.0 .
time_to_second({T1,T2,T3}) ->
	T1 * 1000000 + T2 + T3 / 1000000.0 .

