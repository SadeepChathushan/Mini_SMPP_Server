-module(smpp_session_sup).

-behaviour(supervisor).

-export([
    start_link/0,
    start_session/1,
    init/1
]).

start_link() ->
    supervisor:start_link(
        {local, ?MODULE},
        ?MODULE,
        []
    ).

start_session(Socket) ->
    supervisor:start_child(
        ?MODULE,
        [Socket]
    ).

init([]) ->
    SessionChild = #{
        id => smpp_session,
        start => {smpp_session, start_link, []},
        restart => temporary,
        shutdown => 5000,
        type => worker,
        modules => [smpp_session]
    },

    SupFlags = #{
        strategy => simple_one_for_one,
        intensity => 10,
        period => 10
    },

    {ok, {SupFlags, [SessionChild]}}.