-module(smpp_session).

-behaviour(gen_server).

-export([
    start_link/1,
    activate/1
]).

-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2
]).

start_link(Socket) ->
    gen_server:start_link(
        ?MODULE,
        Socket,
        []
    ).

activate(Pid) ->
    gen_server:cast(
        Pid,
        activate
    ).

init(Socket) ->
    io:format(
        "New SMPP session process started: ~p~n",
        [self()]
    ),

    State = #{
        socket => Socket,
        bound => false,
        system_id => undefined
    },

    {ok, State}.

handle_cast(activate, State) ->
    Socket =
        maps:get(
            socket,
            State
        ),

    ok =
        inet:setopts(
            Socket,
            [{active, once}]
        ),

    io:format(
        "Session activated: ~p~n",
        [self()]
    ),

    {noreply, State};

handle_cast(_Message, State) ->
    {noreply, State}.

handle_info(
    {tcp, Socket, Data},
    State
) ->
    io:format(
        "Session ~p received data: ~p~n",
        [self(), Data]
    ),

    NewState =
        handle_client_data(
            Socket,
            Data,
            State
        ),

    ok =
        inet:setopts(
            Socket,
            [{active, once}]
        ),

    {noreply, NewState};

handle_info(
    {tcp_closed, _Socket},
    State
) ->
    io:format(
        "Client disconnected from session: ~p~n",
        [self()]
    ),

    {stop, normal, State};

handle_info(
    {tcp_error, _Socket, Reason},
    State
) ->
    io:format(
        "TCP error in session ~p: ~p~n",
        [self(), Reason]
    ),

    {stop, Reason, State};

handle_info(_Info, State) ->
    {noreply, State}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

terminate(_Reason, State) ->
    case maps:find(socket, State) of
        {ok, Socket} ->
            catch gen_tcp:close(Socket);

        error ->
            ok
    end,

    ok.

handle_client_data(
    Socket,
    Data,
    State
) ->
    CleanData =
        string:trim(
            binary_to_list(Data)
        ),

    Parts =
        string:tokens(
            CleanData,
            " "
        ),

    handle_command(
        Socket,
        Parts,
        State
    ).

handle_command(
    Socket,
    ["BIND", Username, Password],
    State
) ->
    UsernameBin =
        list_to_binary(Username),

    PasswordBin =
        list_to_binary(Password),

    case smpp_auth:authenticate(
        UsernameBin,
        PasswordBin
    ) of
        true ->
            io:format(
                "Bind successful for ~p~n",
                [UsernameBin]
            ),

            ok =
                gen_tcp:send(
                    Socket,
                    <<"BIND_OK\r\n">>
                ),

            State#{
                bound => true,
                system_id => UsernameBin
            };

        false ->
            io:format(
                "Bind failed for ~p~n",
                [UsernameBin]
            ),

            ok =
                gen_tcp:send(
                    Socket,
                    <<"BIND_FAIL\r\n">>
                ),

            State
    end;

handle_command(
    Socket,
    _Parts,
    State
) ->
    ok =
        gen_tcp:send(
            Socket,
            <<"UNKNOWN_COMMAND\r\n">>
        ),

    State.