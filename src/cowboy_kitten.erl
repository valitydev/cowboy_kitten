-module(cowboy_kitten).
-behaviour(cowboy_stream).

%% callback exports

-export([init/3]).
-export([data/4]).
-export([info/3]).
-export([terminate/3]).
-export([early_error/5]).

-type state() :: #{
    next := any(),
    resp_bodies := resp_bodies()
}.

-type resp_body() :: {file, file:name_all()} | iodata().

-type resp_bodies() :: #{
    cowboy:http_status() => resp_body()
}.

%% callbacks

-spec init(cowboy_stream:streamid(), cowboy_req:req(), cowboy:opts())
    -> {cowboy_stream:commands(), state()}.
init(StreamID, Req, Opts) ->
    {Commands0, Next} = cowboy_stream:init(StreamID, Req, Opts),
    {Commands0, make_state(Next, Opts)}.

-spec data(cowboy_stream:streamid(), cowboy_stream:fin(), cowboy_req:resp_body(), State)
    -> {cowboy_stream:commands(), State} when State::state().
data(StreamID, IsFin, Data, #{next := Next0} = State) ->
    {Commands0, Next} = cowboy_stream:data(StreamID, IsFin, Data, Next0),
    {Commands0, State#{next => Next}}.

-spec info(cowboy_stream:streamid(), any(), State)
    -> {cowboy_stream:commands(), State} when State::state().
info(StreamID, {response, _, _, _} = Info, #{next := Next0} = State) ->
    Resp1 = handle_response(Info, State),
    {Commands0, Next} = cowboy_stream:info(StreamID, Resp1, Next0),
    {Commands0, State#{next => Next}};
info(StreamID, Info, #{next := Next0} = State) ->
    {Commands0, Next} = cowboy_stream:info(StreamID, Info, Next0),
    {Commands0, State#{next => Next}}.

-spec terminate(cowboy_stream:streamid(), cowboy_stream:reason(), state()) -> any().
terminate(StreamID, Reason, #{next := Next}) ->
    cowboy_stream:terminate(StreamID, Reason, Next).

-spec early_error(cowboy_stream:streamid(), cowboy_stream:reason(),
    cowboy_stream:partial_req(), Resp, cowboy:opts()) -> Resp
    when Resp::cowboy_stream:resp_command().
early_error(StreamID, Reason, PartialReq, Resp, Opts) ->
    Resp1 = handle_response(Resp, Opts),
    cowboy_stream:early_error(StreamID, Reason, PartialReq, Resp1, Opts).

%% private functions

handle_response({response, Code, Headers, Body} = Resp, #{resp_bodies := RespBodies}) ->
    case maps:is_key(Code, RespBodies) of
        true ->
            respond_with_body(Code, Headers, get_resp_body(Code, RespBodies), Body);
        false ->
            Resp
    end.


respond_with_body(Code, Headers, undefined, Body) ->
    {response, Code, Headers, Body};
respond_with_body(Code, Headers0, RespBody, _) ->
    Size = get_body_length(RespBody),
    Headers = maps:merge(Headers0, #{
        <<"content-type">> => <<"text/plain; charset=utf-8">>,
        <<"content-length">> => integer_to_list(Size)
    }),
    Body = case RespBody of
        {file, File} ->
            {sendfile, 0, Size, File};
        Binary ->
            Binary
    end,
    {response, Code, Headers, Body}.

get_body_length({file, File}) ->
    filelib:file_size(File);
get_body_length(Binary) ->
    string:length(Binary).

get_resp_body(Code, RespBodies) ->
    do_get_resp_body(Code, genlib_map:get(Code, RespBodies)).

do_get_resp_body(Code, {file, Filename} = File) ->
    case file_exists(Filename) of
        true ->
            File;
        false ->
            _ = logger:warning(
                "Invalid resp body config for code: ~p, file ~p doesn't exist .",
                [Code, Filename]
            ),
            undefined
    end;
do_get_resp_body(_, Binary) when is_binary(Binary) ->
    Binary;
do_get_resp_body(Code, _) ->
    _ = logger:warning("Invalid resp body config for code: ~p, wrong type.", [Code]),
    undefined.

file_exists(Filename) ->
    filelib:is_regular(Filename). % we can count irregular files as non-existent

make_state(Next, Opts) ->
    #{
        next => Next,
        resp_bodies => get_resp_bodies(Opts)
    }.

get_resp_bodies(#{env := Env}) ->
    genlib_map:get(resp_bodies, Env, #{}).

-ifdef(TEST).
-include_lib("eunit/include/eunit.hrl").

-define(KITTEN, "data/ascii_cat").

-spec test() -> _.

-spec success_kitten_file_test() -> _.

success_kitten_file_test() ->
    {ok, CWD} = file:get_cwd(),
    KittenFile = filename:join(CWD, ?KITTEN),
    R = handle_response({response, 500, #{}, <<"OLD BODY">>}, #{resp_bodies => #{500 => {file, KittenFile}}}),
    {_, _, _, {sendfile, _, _, KittenFile}} = R.

-spec success_kitten_binary_test() -> _.

success_kitten_binary_test() ->
    {ok, Kitten} = file:read_file(?KITTEN),
    {_, _, _, Kitten} = handle_response({response, 500, #{}, <<"OLD BODY">>}, #{resp_bodies => #{500 => Kitten}}).

-spec no_replacement_test() -> _.

no_replacement_test() ->
    Body = <<"Can't replace me">>,
    {_, _, _, Body} = handle_response({response, 500, #{}, Body}, #{resp_bodies => #{503 => <<"Unrelated">>}}).

-endif.
