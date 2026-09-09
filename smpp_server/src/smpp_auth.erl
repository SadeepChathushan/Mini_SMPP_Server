-module(smpp_auth).

-export([
    authenticate/2
]).

authenticate(
    <<"testuser">>,
    <<"test123">>
) ->
    true;

authenticate(_, _) ->
    false.