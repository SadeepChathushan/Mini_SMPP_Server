-module(delivery_worker).

-export([
    send_delivery_receipt/3
]).


send_delivery_receipt(
    Socket,
    MessageId,
    Delay
) ->

    spawn(
        fun() ->

            io:format(
                "Waiting ~p ms before delivering ~p~n",
                [
                    Delay,
                    MessageId
                ]
            ),

            timer:sleep(
                Delay
            ),

            case message_store:update_status(
                MessageId,
                delivered
            ) of

                ok ->

                    Response =
                        <<
                            "DELIVERED ",
                            MessageId/binary,
                            "\r\n"
                        >>,

                    case gen_tcp:send(
                        Socket,
                        Response
                    ) of

                        ok ->
                            io:format(
                                "Delivery receipt sent for ~p~n",
                                [MessageId]
                            );

                        {error, Reason} ->
                            io:format(
                                "Failed to send delivery receipt for ~p: ~p~n",
                                [
                                    MessageId,
                                    Reason
                                ]
                            )
                    end;

                not_found ->
                    io:format(
                        "Message not found: ~p~n",
                        [MessageId]
                    )
            end

        end
    ),

    ok.