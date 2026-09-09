-module(message_store).

-behaviour(gen_server).

-export([
    start_link/0,
    save/1,
    find/1,
    update_status/2
]).

-export([
    init/1,
    handle_call/3,
    handle_cast/2,
    handle_info/2,
    terminate/2
]).

-define(TABLE, smpp_messages).


%% ============================================================
%% Public API
%% ============================================================

start_link() ->
    gen_server:start_link(
        {local, ?MODULE},
        ?MODULE,
        [],
        []
    ).


save(Message) ->
    gen_server:call(
        ?MODULE,
        {save, Message}
    ).


find(MessageId) ->
    gen_server:call(
        ?MODULE,
        {find, MessageId}
    ).


update_status(MessageId, Status) ->
    gen_server:call(
        ?MODULE,
        {update_status, MessageId, Status}
    ).


%% ============================================================
%% gen_server callbacks
%% ============================================================

init([]) ->

    ets:new(
        ?TABLE,
        [
            named_table,
            public,
            set
        ]
    ),

    io:format(
        "Message store started~n"
    ),

    {ok, #{}}.


%% ------------------------------------------------------------
%% Save new SMS
%% ------------------------------------------------------------

handle_call(
    {save, Message},
    _From,
    State
) ->

    MessageId =
        maps:get(
            message_id,
            Message
        ),

    ets:insert(
        ?TABLE,
        {
            MessageId,
            Message
        }
    ),

    io:format(
        "Message stored: ~p~n",
        [MessageId]
    ),

    {reply, ok, State};


%% ------------------------------------------------------------
%% Find SMS
%% ------------------------------------------------------------

handle_call(
    {find, MessageId},
    _From,
    State
) ->

    Result =
        case ets:lookup(
            ?TABLE,
            MessageId
        ) of

            [{MessageId, Message}] ->
                {ok, Message};

            [] ->
                not_found
        end,

    {reply, Result, State};


%% ------------------------------------------------------------
%% Update SMS status
%% ------------------------------------------------------------

handle_call(
    {update_status, MessageId, Status},
    _From,
    State
) ->

    Result =
        case ets:lookup(
            ?TABLE,
            MessageId
        ) of

            [{MessageId, Message}] ->

                UpdatedMessage =
                    Message#{
                        status => Status
                    },

                ets:insert(
                    ?TABLE,
                    {
                        MessageId,
                        UpdatedMessage
                    }
                ),

                io:format(
                    "Message ~p status updated to ~p~n",
                    [
                        MessageId,
                        Status
                    ]
                ),

                ok;

            [] ->
                not_found
        end,

    {reply, Result, State}.


handle_cast(
    _Message,
    State
) ->
    {noreply, State}.


handle_info(
    _Info,
    State
) ->
    {noreply, State}.


terminate(
    _Reason,
    _State
) ->
    ok.