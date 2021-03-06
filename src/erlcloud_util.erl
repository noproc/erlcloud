-module(erlcloud_util).
-export([sha_mac/2, sha256_mac/2, md5/1, sha256/1,is_dns_compliant_name/1,
         query_all/4, query_all/5, make_response/2, get_items/2, to_string/1]).

-define(MAX_ITEMS, 1000).

sha_mac(K, S) ->
    try
        crypto:hmac(sha, K, S)
    catch
        error:undef ->
            R0 = crypto:hmac_init(sha, K),
            R1 = crypto:hmac_update(R0, S),
            crypto:hmac_final(R1)
    end.

sha256_mac(K, S) ->
    try
        crypto:hmac(sha256, K, S)
    catch
        error:undef ->
            R0 = crypto:hmac_init(sha256, K),
            R1 = crypto:hmac_update(R0, S),
            crypto:hmac_final(R1)
    end.

sha256(V) ->
    try
        crypto:hash(sha256, V)
    catch
        _:_ ->
            crypto:sha256(V)
    end.

md5(V) ->
    try
        crypto:hash(md5, V)
    catch
        _:_ ->
            crypto:md5(V)
    end.

-spec is_dns_compliant_name(string()) -> boolean().
is_dns_compliant_name(Name) ->
    RegExp = "^(([a-z0-9]|[a-z0-9][a-z0-9\\-]*[a-z0-9])\\.)*([a-z0-9]|[a-z0-9][a-z0-9\\-]*[a-z0-9])$",
    case re:run(Name, RegExp) of
        nomatch ->
            false;
        _ ->
            true
    end.


query_all(QueryFun, Config, Action, Params) ->
    query_all(QueryFun, Config, Action, Params, ?MAX_ITEMS, undefined, []).

query_all(QueryFun, Config, Action, Params, MaxItems) ->
    query_all(QueryFun, Config, Action, Params, MaxItems, undefined, []).

query_all(QueryFun, Config, Action, Params, MaxItems, Marker, Acc) ->
    MarkerParams = case Marker of
                    undefined ->
                        Params;
                    _ ->
                        [{"Marker", Marker} | Params]
                end,
    NewParams = [{"MaxItems", MaxItems} | MarkerParams],
    case QueryFun(Config, Action, NewParams) of
        {ok, Doc} ->
            IsTruncated = erlcloud_xml:get_bool("/*/*/IsTruncated", Doc),
            NewMarker = erlcloud_xml:get_text("/*/*/Marker", Doc),
            Queried = [Doc | Acc],
            case IsTruncated of
                true ->
                    query_all(QueryFun, Config, Action, Params,
                              MaxItems, NewMarker, Queried);
                false ->
                    {ok, lists:reverse(Queried)}
            end;
        Error ->
            Error
    end.


make_response(Xml, Result) ->
    IsTruncated = erlcloud_xml:get_bool("/*/*/IsTruncated", Xml),
    Marker = erlcloud_xml:get_text("/*/*/Marker", Xml),
    case IsTruncated of
        false ->
            {ok, Result};
        true ->
            {ok, Result, Marker}
    end.


get_items(ItemPath, Xmls) when is_list(Xmls) ->
    lists:append([get_items(ItemPath, Xml) || Xml <- Xmls]);
get_items(ItemPath, Xml) ->
    xmerl_xpath:string(ItemPath, Xml).

-spec to_string(string() | integer()) -> string().
to_string(X) when is_list(X)              -> X;
to_string(X) when is_integer(X) -> integer_to_list(X).
