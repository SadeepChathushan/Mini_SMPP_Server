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


%% ============================================================
%% Public API
%% ============================================================

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


%% ============================================================
%% gen_server init
%% ============================================================

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


%% ============================================================
%% handle_cast
%% ============================================================

handle_cast(
    activate,
    State
) ->

    Socket =
        maps:get(
            socket,
            State
        ),

    ok =
        inet:setopts(
            Socket,
            [
                {active, once}
            ]
        ),

    io:format(
        "Session activated: ~p~n",
        [self()]
    ),

    {noreply, State};


handle_cast(
    _Message,
    State
) ->
    {noreply, State}.


%% ============================================================
%% TCP data
%% ============================================================

handle_info(
    {tcp, Socket, Data},
    State
) ->

    io:format(
        "~nReceived from client: ~p~n",
        [Data]
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
            [
                {active, once}
            ]
        ),

    {noreply, NewState};


%% ============================================================
%% TCP closed
%% ============================================================

handle_info(
    {tcp_closed, _Socket},
    State
) ->

    io:format(
        "Client disconnected from session: ~p~n",
        [self()]
    ),

    {stop, normal, State};


%% ============================================================
%% TCP error
%% ============================================================

handle_info(
    {tcp_error, _Socket, Reason},
    State
) ->

    io:format(
        "TCP error in session ~p: ~p~n",
        [
            self(),
            Reason
        ]
    ),

    {stop, Reason, State};


handle_info(
    _Info,
    State
) ->
    {noreply, State}.


%% ============================================================
%% handle_call
%% ============================================================

handle_call(
    _Request,
    _From,
    State
) ->
    {reply, ok, State}.


%% ============================================================
%% Terminate session
%% ============================================================

terminate(
    _Reason,
    State
) ->

    case maps:find(
        socket,
        State
    ) of

        {ok, Socket} ->
            catch gen_tcp:close(
                Socket
            );

        error ->
            ok
    end,

    ok.


%% ============================================================
%% Parse client data
%% ============================================================

handle_client_data(
    Socket,
    Data,
    State
) ->

    CleanData =
        string:trim(
            binary_to_list(
                Data
            )
        ),

    Parts =
        string:tokens(
            CleanData,
            " "
        ),

    io:format(
        "Parsed command: ~p~n",
        [Parts]
    ),

    handle_command(
        Socket,
        Parts,
        State
    ).


%% ============================================================
%% BIND
%% ============================================================

handle_command(
    Socket,
    ["BIND", Username, Password],
    State
) ->

    UsernameBin =
        list_to_binary(
            Username
        ),

    PasswordBin =
        list_to_binary(
            Password
        ),

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


%% ============================================================
%% SUBMIT SMS
%% ============================================================

handle_command(
    Socket,
    [
        "SUBMIT",
        Sender,
        Receiver
        | MessageParts
    ],
    State
) ->

    case maps:get(
        bound,
        State
    ) of

        false ->

            io:format(
                "SUBMIT rejected. Client is not bound.~n"
            ),

            ok =
                gen_tcp:send(
                    Socket,
                    <<"ERROR_NOT_BOUND\r\n">>
                ),

            State;


        true ->

            %% ------------------------------------------------
            %% Join SMS body
            %% ------------------------------------------------

            Message =
                string:join(
                    MessageParts,
                    " "
                ),

            %% ------------------------------------------------
            %% Generate globally unique message ID
            %% ------------------------------------------------

            MessageId =
                generate_message_id(),

            %% ------------------------------------------------
            %% Convert values to binaries
            %% ------------------------------------------------

            SenderBin =
                list_to_binary(
                    Sender
                ),

            ReceiverBin =
                list_to_binary(
                    Receiver
                ),

            MessageBin =
                list_to_binary(
                    Message
                ),

            SystemId =
                maps:get(
                    system_id,
                    State
                ),

            %% ------------------------------------------------
            %% Build SMS record
            %% ------------------------------------------------

            SmsRecord = #{
                message_id => MessageId,
                system_id => SystemId,
                source => SenderBin,
                destination => ReceiverBin,
                message => MessageBin,
                status => accepted
            },

            %% ------------------------------------------------
            %% Save SMS
            %% ------------------------------------------------

            ok =
                message_store:save(
                    SmsRecord
                ),

            io:format(
                "~nSMS ACCEPTED~n"
                "--------------------------~n"
                "Message ID : ~p~n"
                "System ID  : ~p~n"
                "From       : ~p~n"
                "To         : ~p~n"
                "Message    : ~p~n"
                "Status     : accepted~n"
                "--------------------------~n",
                [
                    MessageId,
                    SystemId,
                    SenderBin,
                    ReceiverBin,
                    MessageBin
                ]
            ),

            %% ------------------------------------------------
            %% Send SUBMIT response
            %% ------------------------------------------------

            Response =
                <<
                    "SUBMIT_OK ",
                    MessageId/binary,
                    "\r\n"
                >>,

            ok =
                gen_tcp:send(
                    Socket,
                    Response
                ),

            %% ------------------------------------------------
            %% Simulate delivery after 3 seconds
            %% ------------------------------------------------

            delivery_worker:send_delivery_receipt(
                Socket,
                MessageId,
                3000
            ),

            State
    end;


%% ============================================================
%% Unknown command
%% ============================================================

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


%% ============================================================
%% Generate Message ID
%% ============================================================

generate_message_id() ->

    Number =
        erlang:unique_integer(
            [
                positive,
                monotonic
            ]
        ),

    NumberBin =
        integer_to_binary(
            Number
        ),

    <<
        "MSG",
        NumberBin/binary
    >>.