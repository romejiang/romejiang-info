%%%----------------------------------------------------------------------
%%% File    : mod_ping.erl
%%% Author  : rome jiang <romejiang@gmail.com> 
%%% Purpose : each message send ping. check user online.
%%% Created : 2011 10 17 sifang.com
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
-behavior(gen_mod).
-behavior(gen_server).

-include("ejabberd.hrl").
-include("jlib.hrl").

-define(SUPERVISOR, ejabberd_sup). % 订阅的事件名
-define(NS_PING, "urn:xmpp:ping"). % ping 的命名空间
-define(DEFAULT_SEND_PINGS, false). % bool()
-define(DEFAULT_PING_INTERVAL, 60). % seconds
-define(VHOST, "msn.sifang.com"). % seconds

%% define ETS table , store history message 
-define(ETS_TABLE,history_message).
%% define history message timeout
-define(IQ_TIMEOUT, 32 + 1). 

%% API
-export([start_link/2, start_ping/2, stop_ping/2]).

%% gen_mod callbacks
-export([start/2, stop/1]).

%% gen_server callbacks
-export([init/1, terminate/2, handle_call/3, handle_cast/2,
         handle_info/2, code_change/3]).

%% Hook callbacks
-export([iq_ping/3, user_offline/3, user_send/4]).

%% Internal functions  
-export([time_to_second/1,kick_sessions/3,kick_this_session/4]).

%% state structure
-record(state, {host = "",
        send_pings = ?DEFAULT_SEND_PINGS}).

-record(session, {sid, usr, us, priority, info}).

-record(offline_msg, {user, timestamp, expire, from, to, packet}).
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
	?INFO_MSG("init config ~p" , [Host]),
    SendPings = gen_mod:get_opt(send_pings, Opts, ?DEFAULT_SEND_PINGS),
    mod_disco:register_feature(Host, ?NS_PING),
    %%IQDisc = gen_mod:get_opt(iqdisc, Opts, no_queue),
    %% register namespace etc: urn:xmpp:ping
    %% register iq callback funciont iq_ping
    %%gen_iq_handler:add_iq_handler(ejabberd_sm, Host, ?NS_PING,
    %%                              ?MODULE, iq_ping, IQDisc),
    %%gen_iq_handler:add_iq_handler(ejabberd_local, Host, ?NS_PING,
    %%                              ?MODULE, iq_ping, IQDisc),
    %% register callback funciton online, offline,user_send
    case SendPings of
        true ->
            ejabberd_hooks:add(sm_remove_connection_hook, Host,
                               ?MODULE, user_offline, 100),
            ejabberd_hooks:add(user_receive_packet, Host,
                               ?MODULE, user_send, 100);
        _ ->
            ok
    end,
    ets:new(?ETS_TABLE , [ordered_set, public, named_table, {write_concurrency, true}]),
    {ok, #state{host = Host,
            send_pings = SendPings}}.

terminate(_Reason, #state{host = Host}) ->
    ejabberd_hooks:delete(sm_remove_connection_hook, Host,
              ?MODULE, user_offline, 100),
    ejabberd_hooks:delete(user_receive_packet, Host,
              ?MODULE, user_send, 100),
    %%gen_iq_handler:remove_iq_handler(ejabberd_local, Host, ?NS_PING),
    %%gen_iq_handler:remove_iq_handler(ejabberd_sm, Host, ?NS_PING),
    mod_disco:unregister_feature(Host, ?NS_PING).

handle_call(stop, _From, State) ->
    {stop, normal, ok, State};
handle_call(_Req, _From, State) ->
    {reply, {error, badarg}, State}.
%% send ping iq-message 
handle_cast({start_ping, JID}, State) ->
    ?INFO_MSG("send ping iq-message: ~p", [JID]),
    IQ = #iq{type = get,
        sub_el = [{xmlelement, "ping", [{"xmlns", ?NS_PING}], []}]},
    Pid = self(),
	F = fun(Response) ->
        gen_server:cast(Pid, {iq_pong, JID, Response})
    end,
    From = jlib:make_jid("", State#state.host, ""),
    ejabberd_local:route_iq(From, JID, IQ, F),
    
	%%lists:map(fun(Resource) ->
    %%        ejabberd_local:route_iq(From, jlib:jid_replace_resource(JID, Resource), IQ, 
    %%            fun(Response) ->gen_server:cast(Pid, {iq_pong, jlib:jid_replace_resource(JID, Resource) , Response}) end)
    %%    end,
    %%    get_resources(User, Server)),
    {noreply, State};
handle_cast({stop_ping, _JID}, State) ->
    {noreply, State};
%% IQ message timeout
handle_cast({iq_pong, JID, timeout}, State) ->
	ejabberd_hooks:run(user_ping_timeout, State#state.host, [JID]),
    #jid{user = User, server = Server, resource = Resource} = JID,
    %%kick_sessions(User, Server, "timeout"),
    %%resend_history_message(JID);
    case ejabberd_sm:get_session_pid(User, Server, Resource) of
    Pid when is_pid(Pid) ->
        ?INFO_MSG("ping not receive so stop session ~p" , [JID]),		
        ejabberd_c2s:stop(Pid);
        %%resend_history_message(JID);
    _ ->
        ok
    end,
    {noreply, State};
%% Received a reply
handle_cast({iq_pong, JID, #iq{type = Type}    = _IQquery}, State) ->
    case Type of
        %% FEATURE_NOT_IMPLEMENTED
        error ->
            ?INFO_MSG("what is come here ??", []),
            %%gen_server:cast(self(), {iq_pong, JID, timeout});
            clean_history_message(JID);
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
    case {Type, SubEl} of
        {get, {xmlelement, "ping", _, _}} ->
            IQ#iq{type = result, sub_el = []};
        _ ->
            IQ#iq{type = error, sub_el = [SubEl, ?ERR_FEATURE_NOT_IMPLEMENTED]}
    end.
%% user offline so resend history message 
user_offline(_SID, JID, _Info) ->
    ?INFO_MSG("user offline save history message! ~p" , [JID]),
    resend_history_message(JID),
    stop_ping(JID#jid.lserver, JID).

user_send(JID, From , To, {xmlelement, "message", _, _} = Packet) ->
	?INFO_MSG("user_send_packet ~p ~p ~p",[JID , From , To]),
    case xml:get_subtag_cdata(Packet, "body") of
        "" ->
            ok;
        _Body ->
            case xml:get_tag_attr_s("type", Packet) of
                "error" ->
                    ?ERROR_MSG("Received error message~n~p -> ~p~n~p", [From, JID, Packet]);
                _ ->
					?INFO_MSG("insert ETS and send ping message~", []),
					start_ping(JID#jid.lserver,JID),
					JIDlet = jlib:jid_remove_resource(JID), 
                    ets:insert(?ETS_TABLE ,{erlang:now(), JIDlet, From, Packet})
            end
    end;
user_send(_JID , _From , _To,_) ->
    ok.
%%====================================================================
%% Internal functions
%%====================================================================
clean_history_message(JIDFull) ->
    JID = jlib:jid_remove_resource(JIDFull),
    Es = ets:select(?ETS_TABLE,[{{'_',JID,'_','_'},[],['$_']}]),
    lists:foreach(fun({ID, _JID, _From, _Packet}) ->
            TimeDiff = time_diff(ID , erlang:now()),
            if
                TimeDiff > ?IQ_TIMEOUT -> ets:delete(?ETS_TABLE, ID);
                   true -> ok 
            end
        end, Es).

resend_history_message(JIDFull) ->
    JID = jlib:jid_remove_resource(JIDFull), 
    Es = ets:select(?ETS_TABLE,[{{'_',JID,'_','_'},[],['$_']}]),
    lists:foreach(fun({ID, _JID, From, Packet}) ->
            TimeDiff = time_diff(ID , erlang:now()),
            if
                TimeDiff > ?IQ_TIMEOUT -> ok;
                true -> 
                    %%ejabberd_router:route(From, JID, Packet)
					?INFO_MSG("store history message ~p to ~p", [From , JID]),
                    store_packet(From, JID, Packet)
            end,
            ets:delete(?ETS_TABLE, ID)
        end, Es).
time_diff({A1,A2,A3}, {B1,B2,B3}) -> 
    (B1 - A1) * 1000000 + (B2 - A2) + (B3 - A3) / 1000000.0 .
time_to_second({T1,T2,T3}) ->
    T1 * 1000000 + T2 + T3 / 1000000.0 .
store_packet(From, To, Packet) ->
    Type = xml:get_tag_attr_s("type", Packet),
    if
    (Type /= "error") and (Type /= "groupchat") and
    (Type /= "headline") ->
        case check_event_chatstates(From, To, Packet) of
        true ->
            #jid{luser = LUser} = To,
            TimeStamp = now(),
            {xmlelement, _Name, _Attrs, Els} = Packet,
            Expire = find_x_expire(TimeStamp, Els),
            gen_mod:get_module_proc(To#jid.lserver, ejabberd_offline) !
            #offline_msg{user = LUser,                                                                                                                              
                     timestamp = TimeStamp,
                     expire = Expire,
                     from = From,
                     to = To,
                     packet = Packet},
            stop;
        _ ->
            ok
        end;
    true ->
        ok
    end.
%% Check if the packet has any content about XEP-0022 or XEP-0085
check_event_chatstates(From, To, Packet) ->
    {xmlelement, Name, Attrs, Els} = Packet,
    case find_x_event_chatstates(Els, {false, false, false}) of
    %% There wasn't any x:event or chatstates subelements
    {false, false, _} ->
        true;
    %% There a chatstates subelement and other stuff, but no x:event
    {false, CEl, true} when CEl /= false ->
        true;
    %% There was only a subelement: a chatstates
    {false, CEl, false} when CEl /= false ->
        %% Don't allow offline storage
        false;
    %% There was an x:event element, and maybe also other stuff
    {El, _, _} when El /= false ->
        case xml:get_subtag(El, "id") of
        false ->
            case xml:get_subtag(El, "offline") of
            false ->
                true;
            _ ->
                ID = case xml:get_tag_attr_s("id", Packet) of
                     "" ->
                     {xmlelement, "id", [], []};
                     S ->
                     {xmlelement, "id", [],
                      [{xmlcdata, S}]}
                 end,
                ejabberd_router:route(
                  To, From, {xmlelement, Name, Attrs,
                     [{xmlelement, "x",
                       [{"xmlns", ?NS_EVENT}],
                       [ID,
                        {xmlelement, "offline", [], []}]}]
                    }),
                true
            end;
        _ ->
            false
        end
    end.

%% Check if the packet has subelements about XEP-0022, XEP-0085 or other
find_x_event_chatstates([], Res) ->
    Res;
find_x_event_chatstates([{xmlcdata, _} | Els], Res) ->
    find_x_event_chatstates(Els, Res);
find_x_event_chatstates([El | Els], {A, B, C}) ->
    case xml:get_tag_attr_s("xmlns", El) of
    ?NS_EVENT ->
        find_x_event_chatstates(Els, {El, B, C});
    ?NS_CHATSTATES ->
        find_x_event_chatstates(Els, {A, El, C});
    _ ->
        find_x_event_chatstates(Els, {A, B, true})
    end.

find_x_expire(_, []) ->
    never;
find_x_expire(TimeStamp, [{xmlcdata, _} | Els]) ->
    find_x_expire(TimeStamp, Els);
find_x_expire(TimeStamp, [El | Els]) ->
    case xml:get_tag_attr_s("xmlns", El) of
    ?NS_EXPIRE ->
        Val = xml:get_tag_attr_s("seconds", El),
        case catch list_to_integer(Val) of
        {'EXIT', _} ->
            never;
        Int when Int > 0 ->
            {MegaSecs, Secs, MicroSecs} = TimeStamp,
            S = MegaSecs * 1000000 + Secs + Int,
            MegaSecs1 = S div 1000000,
            Secs1 = S rem 1000000,
            {MegaSecs1, Secs1, MicroSecs};
        _ ->
            never
        end;
    _ ->
        find_x_expire(TimeStamp, Els)
    end.
kick_sessions(User, Server, Reason) ->
    lists:map(
      fun(Resource) ->
          kick_this_session(User, Server, Resource, Reason)
      end,
      get_resources(User, Server)).

get_resources(User, Server) ->
    lists:map(
      fun(Session) ->
          element(3, Session#session.usr)
      end,
      get_sessions(User, Server)).

get_sessions(User, Server) ->
    LUser = jlib:nodeprep(User),
    LServer = jlib:nameprep(Server),
    Sessions =  mnesia:dirty_index_read(session, {LUser, LServer}, #session.us),
    true = is_list(Sessions),
    Sessions.

kick_this_session(User, Server, Resource, Reason) ->
    ejabberd_router:route(
      jlib:make_jid("", "", ""),
      jlib:make_jid(User, Server, Resource),
      {xmlelement, "broadcast", [], [{exit, Reason}]}).
