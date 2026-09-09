-module(smpp_listener).

-behaviour(gen_server).

-export([
    start_link/0
]).

-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2
]).

-define(PORT, 2775).

start_link() ->
    gen_server:start_link(
        {local, ?MODULE},
        ?MODULE,
        [],
        []
    ).

init([]) ->
    Options = [
        binary,
        {packet, raw},
        {active, false},
        {reuseaddr, true}
    ],

    case gen_tcp:listen(?PORT, Options) of
        {ok, ListenSocket} ->
            io:format(
                "SMPP server listening on port ~p~n",
                [?PORT]
            ),

            self() ! accept,

            {ok, #{
                listen_socket => ListenSocket
            }};

        {error, Reason} ->
            {stop, Reason}
    end.

handle_info(accept, State) ->
    ListenSocket =
        maps:get(
            listen_socket,
            State
        ),

    io:format(
        "Waiting for SMPP client...~n"
    ),

    case gen_tcp:accept(ListenSocket) of
        {ok, Socket} ->
            io:format(
                "Client connected: ~p~n",
                [Socket]
            ),

            case smpp_session_sup:start_session(Socket) of
                {ok, SessionPid} ->
                    ok =
                        gen_tcp:controlling_process(
                            Socket,
                            SessionPid
                        ),

                    smpp_session:activate(
                        SessionPid
                    );

                {error, Reason} ->
                    io:format(
                        "Failed to start session: ~p~n",
                        [Reason]
                    ),

                    gen_tcp:close(Socket)
            end,

            self() ! accept,

            {noreply, State};

        {error, Reason} ->
            io:format(
                "Accept failed: ~p~n",
                [Reason]
            ),

            self() ! accept,

            {noreply, State}
    end;

handle_info(_Info, State) ->
    {noreply, State}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Message, State) ->
    {noreply, State}.

terminate(_Reason, State) ->
    case maps:find(
        listen_socket,
        State
    ) of
        {ok, ListenSocket} ->
            gen_tcp:close(
                ListenSocket
            );

        error ->
            ok
    end,

    ok.