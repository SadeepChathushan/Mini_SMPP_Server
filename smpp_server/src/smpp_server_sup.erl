-module(smpp_server_sup).

-behaviour(supervisor).

-export([
    start_link/0,
    init/1
]).

start_link() ->
    supervisor:start_link(
        {local, ?MODULE},
        ?MODULE,
        []
    ).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 5,
        period => 10
    },

    SessionSupervisor = #{
        id => smpp_session_sup,
        start => {
            smpp_session_sup,
            start_link,
            []
        },
        restart => permanent,
        shutdown => 5000,
        type => supervisor,
        modules => [smpp_session_sup]
    },

    Listener = #{
        id => smpp_listener,
        start => {
            smpp_listener,
            start_link,
            []
        },
        restart => permanent,
        shutdown => 5000,
        type => worker,
        modules => [smpp_listener]
    },

    Children = [
        SessionSupervisor,
        Listener
    ],

    {ok, {SupFlags, Children}}.