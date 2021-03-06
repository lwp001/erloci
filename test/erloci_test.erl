%% -*- coding: utf-8 -*-
-module(erloci_test).

-include_lib("eunit/include/eunit.hrl").
-include("test_common.hrl").

-define(PORT_MODULE, oci_port).

-define(TESTTABLE, "erloci_test_1").
-define(TESTFUNCTION, "ERLOCI_TEST_FUNCTION").
-define(TESTPROCEDURE, "ERLOCI_TEST_PROCEDURE").
-define(DROP,   <<"drop table "?TESTTABLE>>).
-define(CREATE, <<"create table "?TESTTABLE" (pkey integer,"
                  "publisher varchar2(30),"
                  "rank float,"
                  "hero binary_double,"
                  "reality raw(10),"
                  "votes number(1,-10),"
                  "createdate date default sysdate,"
                  "chapters binary_float,"
                  "votes_first_rank number)">>).
-define(INSERT, <<"insert into "?TESTTABLE
                  " (pkey,publisher,rank,hero,reality,votes,createdate,"
                  "  chapters,votes_first_rank) values ("
                  ":pkey"
                  ", :publisher"
                  ", :rank"
                  ", :hero"
                  ", :reality"
                  ", :votes"
                  ", :createdate"
                  ", :chapters"
                  ", :votes_first_rank)">>).
-define(SELECT_WITH_ROWID, <<"select "?TESTTABLE".rowid, "?TESTTABLE
                             ".* from "?TESTTABLE>>).
-define(SELECT_ROWID_ASC, <<"select rowid from "?TESTTABLE" order by pkey">>).
-define(SELECT_ROWID_DESC, <<"select rowid from "?TESTTABLE
                             " order by pkey desc">>).
-define(BIND_LIST, [ {<<":pkey">>, 'SQLT_INT'}
                   , {<<":publisher">>, 'SQLT_CHR'}
                   , {<<":rank">>, 'SQLT_FLT'}
                   , {<<":hero">>, 'SQLT_IBDOUBLE'}
                   , {<<":reality">>, 'SQLT_BIN'}
                   , {<<":votes">>, 'SQLT_INT'}
                   , {<<":createdate">>, 'SQLT_DAT'}
                   , {<<":chapters">>, 'SQLT_IBFLOAT'}
                   , {<<":votes_first_rank">>, 'SQLT_INT'}
                   ]).
-define(UPDATE, <<"update "?TESTTABLE" set "
                  "pkey = :pkey"
                  ", publisher = :publisher"
                  ", rank = :rank"
                  ", hero = :hero"
                  ", reality = :reality"
                  ", votes = :votes"
                  ", createdate = :createdate"
                  ", chapters = :chapters"
                  ", votes_first_rank = :votes_first_rank"
                  " where "?TESTTABLE".rowid = :pri_rowid1">>).
-define(UPDATE_BIND_LIST, [ {<<":pkey">>, 'SQLT_INT'}
                          , {<<":publisher">>, 'SQLT_CHR'}
                          , {<<":rank">>, 'SQLT_FLT'}
                          , {<<":hero">>, 'SQLT_IBDOUBLE'}
                          , {<<":reality">>, 'SQLT_BIN'}
                          , {<<":votes">>, 'SQLT_STR'}
                          , {<<":createdate">>, 'SQLT_DAT'}
                          , {<<":chapters">>, 'SQLT_IBFLOAT'}
                          , {<<":votes_first_rank">>, 'SQLT_INT'}
                          , {<<":pri_rowid1">>, 'SQLT_STR'}
                          ]).
-define(SESSSQL, <<"select '' || s.sid || ',' || s.serial# "
                   "from gv$session s join "
                   "gv$process p on p.addr = s.paddr and "
                   "p.inst_id = s.inst_id "
                   "where s.type != 'BACKGROUND' and s.program like 'ocierl%'">>).

% ------------------------------------------------------------------------------
% db_negative_test_
% ------------------------------------------------------------------------------
db_negative_test_() ->
    {timeout, 60, {
        setup,
        fun() ->
                Conf = ?CONN_CONF,
                application:start(erloci),
                OciPort = erloci:new(
                            [{logging, true},
                             {env, [{"NLS_LANG",
                                     "GERMAN_SWITZERLAND.AL32UTF8"}]}]),
                #{ociport => OciPort, conf => Conf}
        end,
        fun(#{ociport := OciPort}) ->
                OciPort:close(),
                application:stop(erloci)
        end,
        {with, [
            fun echo/1,
            fun bad_password/1,
            fun session_ping/1
        ]}
    }}.

echo(#{ociport := OciPort}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|                     echo                    |"),
    ?ELog("+---------------------------------------------+"),
    ?ELog("echo back erlang terms", []),
    ?assertEqual(1, OciPort:echo(1)),
    ?assertEqual(1.2, OciPort:echo(1.2)),
    ?assertEqual(atom, OciPort:echo(atom)),
    ?assertEqual(self(), OciPort:echo(self())),
    ?assertEqual(node(), OciPort:echo(node())),
    Ref = make_ref(),
    ?assertEqual(Ref, OciPort:echo(Ref)),
    % Load the ref cache to generate long ref
    Refs = [make_ref() || _I <- lists:seq(1,1000000)],
    ?debugFmt("~p refs created to load ref cache", [length(Refs)]),
    Ref1 = make_ref(),
    ?assertEqual(Ref1, OciPort:echo(Ref1)),
    %Fun = fun() -> ok end, % Not Supported
    %?assertEqual(Fun, OciPort:echo(Fun)),
    ?assertEqual("", OciPort:echo("")),
    ?assertEqual(<<>>, OciPort:echo(<<>>)),
    ?assertEqual([], OciPort:echo([])),
    ?assertEqual({}, OciPort:echo({})),
    ?assertEqual("string", OciPort:echo("string")),
    ?assertEqual(<<"binary">>, OciPort:echo(<<"binary">>)),
    ?assertEqual({1,'Atom',1.2,"string"}, OciPort:echo({1,'Atom',1.2,"string"})),
    ?assertEqual([1, atom, 1.2,"string"], OciPort:echo([1,atom,1.2,"string"])).

bad_password(#{ociport := OciPort, conf := #{tns := Tns, user := User, password := Pswd}}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|                 bad_password                |"),
    ?ELog("+---------------------------------------------+"),
    ?ELog("get_session with wrong password", []),
    ?assertMatch(
       {error, {1017,_}},
       OciPort:get_session(Tns, User, list_to_binary([Pswd,"_bad"]))).

session_ping(#{ociport := OciPort, conf := #{tns := Tns, user := User, password := Pswd}}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|                 session_ping                |"),
    ?ELog("+---------------------------------------------+"),
    ?ELog("ping oci session", []),
    OciSession = OciPort:get_session(Tns, User, Pswd),
    ?assertEqual(pong, OciSession:ping()),
    SelStmt = OciSession:prep_sql("select * from dual"),
    ?assertEqual(pong, OciSession:ping()),
    ?assertMatch({cols,[{<<"DUMMY">>,'SQLT_CHR',_,0,0}]}, SelStmt:exec_stmt()),
    ?assertEqual(pong, OciSession:ping()),
    ?assertEqual({{rows,[[<<"X">>]]},true}, SelStmt:fetch_rows(100)),
    ?assertEqual(pong, OciSession:ping()).

%%------------------------------------------------------------------------------
%% db_test_
%%------------------------------------------------------------------------------
db_test_() ->
    {timeout, 60, {
       setup,
       fun() ->
               Conf = ?CONN_CONF,
               application:start(erloci),
               #{tns := Tns, user := User, password := Pswd,
                 logging := Logging, lang := Lang} = Conf,
               OciPort = erloci:new([{logging, Logging}, {env, [{"NLS_LANG", Lang}]}]),
               OciSession = OciPort:get_session(Tns, User, Pswd),
               ssh(#{ociport => OciPort, ocisession => OciSession, conf => Conf})
       end,
       fun(#{ociport := OciPort, ocisession := OciSession} = State) ->
               DropStmt = OciSession:prep_sql(?DROP),
               DropStmt:exec_stmt(),
               DropStmt:close(),
               OciSession:close(),
               OciPort:close(),
               application:stop(erloci),
               case State of
                   #{ssh_conn_ref := ConRef} ->
                       ok = ssh:close(ConRef);
                   _ -> ok
               end,
               ssh:stop()
       end,
       {with,
        [fun named_session/1,
         fun drop_create/1,
         fun bad_sql_connection_reuse/1,
         fun insert_select_update/1,
         fun auto_rollback/1,
         fun commit_rollback/1,
         fun asc_desc/1,
         fun lob/1,
         fun bfile/1,
         fun describe/1,
         fun function/1,
         fun procedure_scalar/1,
         fun procedure_cur/1,
         fun timestamp_interval_datatypes/1,
         fun stmt_reuse_onerror/1,
         fun multiple_bind_reuse/1,
         fun check_ping/1,
         fun check_session_without_ping/1,
         fun check_session_with_ping/1,
         fun urowid/1
        ]}
      }}.

ssh(#{conf := #{ssh_ip := Ip, ssh_port := Port,
                ssh_user := User, ssh_password := Password}} = State) ->
    ok = ssh:start(),
    case ssh:connect(Ip,Port,[{user,User},{password,Password}]) of
        {ok, ConRef} ->
            State#{ssh_conn_ref => ConRef};
        {error, Reason} ->
            ?ELog("SSH setup error ~p", [Reason]),
            State
    end;
ssh(State) ->
    ?ELog("SSH not configured, some tests will be skipped"),
    State.

flush_table(OciSession) ->
    ?ELog("creating (drop if exists) table ~s", [?TESTTABLE]),
    DropStmt = OciSession:prep_sql(?DROP),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, DropStmt),
    % If table doesn't exists the handle isn't valid
    % Any error is ignored anyway
    case DropStmt:exec_stmt() of
        {error, _} -> ok;
        _ -> ?assertEqual(ok, DropStmt:close())
    end,
    ?ELog("creating table ~s", [?TESTTABLE]),
    StmtCreate = OciSession:prep_sql(?CREATE),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, StmtCreate),
    ?assertEqual({executed, 0}, StmtCreate:exec_stmt()),
    ?assertEqual(ok, StmtCreate:close()).

ssh_cmd(ConRef, Cmd) ->
    {ok, Chn} = ssh_connection:session_channel(ConRef, infinity),
    success = ssh_connection:exec(ConRef, Chn, Cmd, infinity),
    ssh_cmd_result(ConRef, Chn).

ssh_cmd_result(ConRef, Chn) -> ssh_cmd_result(ConRef, Chn, []).
ssh_cmd_result(ConRef, Chn, Buffer) ->
    case receive
             {ssh_cm, ConRef, {closed, Chn}} -> closed;
             {ssh_cm, ConRef, {eof, Chn}} -> eof;
             {ssh_cm, ConRef, {exit_status, Chn, 0}} -> exit_status_ok;
             {ssh_cm, ConRef, {data, Chn, DTC, Data}} ->
                 if DTC /= 0 -> ?ELog("[~p] ~s", [DTC, Data]);
                    true -> ok end,
                 {data, Data};
             {ssh_cm, ConRef, {exit_status, Chn, Exit}} -> {error, {exit_status, Exit}};
             {ssh_cm, ConRef, Other} -> {error, {unexpected, Other}}
         end of
        {data, Dat} -> ssh_cmd_result(ConRef, Chn, [Dat | Buffer]);
        eof -> ssh_cmd_result(ConRef, Chn, Buffer);
        exit_status_ok -> ssh_cmd_result(ConRef, Chn, Buffer);
        closed -> Buffer;
        {error, Error} -> error(Error)
    end.

named_session(#{ociport := OciPort,
                conf := #{tns := Tns, user := User,
                          password := Pswd}}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|                named_session                |"),
    ?ELog("+---------------------------------------------+"),
    OciSession = OciPort:get_session(Tns, User, Pswd, "eunit_test_tagged"),
    StmtSelect = OciSession:prep_sql(
                   <<"select * from V$SESSION"
                     " where CLIENT_IDENTIFIER = 'eunit_test_tagged'">>),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, StmtSelect),
    ?assertMatch({cols, _}, StmtSelect:exec_stmt()),
    ?assertMatch({{rows, _}, true}, StmtSelect:fetch_rows(1)),
    ?assertEqual(ok, StmtSelect:close()),
    OciSession:close().

bfile(#{ocisession := OciSession, ssh_conn_ref := ConRef}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|                     bfile                     |"),
    ?ELog("+---------------------------------------------+"),

    RowCount = 3,

    Files =
    [begin
         ContentSize = rand:uniform(1024),
         Filename = "/tmp/test"++integer_to_list(I)++".bin",
         RCmd = lists:flatten(
                  io_lib:format(
                    "dd if=/dev/zero of=~s bs=~p count=1",
                    [Filename, ContentSize])),
         ssh_cmd(ConRef,RCmd),
         Filename
     end || I <- lists:seq(1,RowCount)],

    CreateDirSql = <<"create or replace directory \"TestDir\" as '/tmp'">>,
    StmtDirCreate = OciSession:prep_sql(CreateDirSql),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, StmtDirCreate),
    case StmtDirCreate:exec_stmt() of
        {executed, 0} ->
            ?ELog("created Directory alias for /tmp"),
            ?assertEqual(ok, StmtDirCreate:close());
        {error, {955, _}} ->
            ?ELog("Dir alias for /tmp exists");
        {error, {N,Error}} ->
            ?ELog("Dir alias for /tmp creation failed ~p:~s", [N,Error]),
            ?ELog("SQL ~s", [CreateDirSql]),
            ?assertEqual("Directory Created", "Directory creation failed")
    end,
    StmtCreate = OciSession:prep_sql(
                   <<"create table b_file(bfiled bfile)">>),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, StmtCreate),
    case StmtCreate:exec_stmt() of
        {executed, 0} ->
            ?ELog("creating table b_file", []),
            ?assertEqual(ok, StmtCreate:close());
        _ ->
            StmtTruncate = OciSession:prep_sql(<<"truncate table b_file">>),
            ?assertMatch({?PORT_MODULE, statement, _, _, _}, StmtTruncate),
            ?assertEqual({executed, 0}, StmtTruncate:exec_stmt()),
            ?ELog("truncated table b_file", []),
            ?assertEqual(ok, StmtTruncate:close())
    end,

    [begin
        StmtInsert = OciSession:prep_sql(list_to_binary(["insert into b_file values("
            "bfilename('TestDir', 'test",integer_to_list(I),".bin')"
            ")"])),
        ?assertMatch({?PORT_MODULE, statement, _, _, _}, StmtInsert),
        ?assertMatch({rowids, [_]}, StmtInsert:exec_stmt()),
        ?assertEqual(ok, StmtInsert:close())
     end
     || I <- lists:seq(1,RowCount)],
    ?ELog("inserted ~p rows into b_file", [RowCount]),

    StmtSelect = OciSession:prep_sql(<<"select * from b_file">>),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, StmtSelect),
    ?assertMatch({cols, _}, StmtSelect:exec_stmt()),
    {{rows, Rows}, true} = StmtSelect:fetch_rows(RowCount+1),
    ?assertEqual(RowCount, length(Rows)),

    lists:foreach(
      fun(Row) ->
              [{LidBfiled, BfiledLen, DirBin, File} | _] = Row,
              ?assertEqual(DirBin, <<"TestDir">>),
              ?ELog("processing... : ~s", [File]),
              [FileContent] = ssh_cmd(ConRef,"cat "++File),
              {lob, FileContentDB} = StmtSelect:lob(LidBfiled, 1, BfiledLen),
              ?assertEqual(FileContent, FileContentDB),
              ?ELog("processed : ~s", [File])
      end, Rows),

    ?assertEqual(ok, StmtSelect:close()),

    ?ELog("RM ~p", [[ssh_cmd(ConRef, "rm -f "++File) || File <- Files]]),
    StmtDrop = OciSession:prep_sql(<<"drop table b_file">>),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, StmtDrop),
    ?assertEqual({executed, 0}, StmtDrop:exec_stmt()),
    ?assertEqual(ok, StmtDrop:close()),
    StmtDirDrop = OciSession:prep_sql(list_to_binary(["drop directory \"TestDir\""])),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, StmtDirDrop),
    ?assertEqual({executed, 0}, StmtDirDrop:exec_stmt()),
    ?assertEqual(ok, StmtDirDrop:close());
bfile(_) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|            bfile (SKIPPED)                    |"),
    ?ELog("+---------------------------------------------+").

lob(#{ocisession := OciSession}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|                     lob                     |"),
    ?ELog("+---------------------------------------------+"),

    RowCount = 3,

    StmtCreate = OciSession:prep_sql(
                   <<"create table lobs(clobd clob, blobd blob, nclobd nclob)">>),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, StmtCreate),
    case StmtCreate:exec_stmt() of
        {executed, 0} ->
            ?ELog("creating table lobs", []),
            ?assertEqual(ok, StmtCreate:close());
        _ ->
            StmtTruncate = OciSession:prep_sql(<<"truncate table lobs">>),
            ?assertMatch({?PORT_MODULE, statement, _, _, _}, StmtTruncate),
            ?assertEqual({executed, 0}, StmtTruncate:exec_stmt()),
            ?ELog("truncated table lobs", []),
            ?assertEqual(ok, StmtTruncate:close())
    end,

    [begin
        StmtInsert = OciSession:prep_sql(list_to_binary(["insert into lobs values("
            "to_clob('clobd0'),"
            "hextoraw('453d7a30'),"
            "to_nclob('nclobd0')"
            ")"])),
        ?assertMatch({?PORT_MODULE, statement, _, _, _}, StmtInsert),
        ?assertMatch({rowids, [_]}, StmtInsert:exec_stmt()),
        ?assertEqual(ok, StmtInsert:close())
     end
     || I <- lists:seq(1,RowCount)],
    ?ELog("inserted ~p rows into lobs", [RowCount]),

    StmtSelect = OciSession:prep_sql(<<"select * from lobs">>),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, StmtSelect),
    ?assertMatch({cols, _}, StmtSelect:exec_stmt()),
    {{rows, Rows}, true} = StmtSelect:fetch_rows(RowCount+1),
    ?assertEqual(RowCount, length(Rows)),

    lists:foreach(
      fun(Row) ->
              [{LidClobd, ClobdLen}, {LidBlobd, BlobdLen}, {LidNclobd, NclobdLen} | _] = Row,
              {lob, ClobDVal} = StmtSelect:lob(LidClobd, 1, ClobdLen),
              ?assertEqual(<<"clobd0">>, ClobDVal),
              {lob, BlobDVal} = StmtSelect:lob(LidBlobd, 1, BlobdLen),
              ?assertEqual(<<16#45, 16#3d, 16#7a, 16#30>>, BlobDVal),
              {lob, NClobDVal} = StmtSelect:lob(LidNclobd, 1, NclobdLen),
              ?assertEqual(<<"nclobd0">>, NClobDVal)
      end, Rows),

    ?assertEqual(ok, StmtSelect:close()),

    StmtDrop = OciSession:prep_sql(<<"drop table lobs">>),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, StmtDrop),
    ?assertEqual({executed, 0}, StmtDrop:exec_stmt()),
    ?assertEqual(ok, StmtDrop:close()).

drop_create(#{ocisession := OciSession}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|                   drop_create               |"),
    ?ELog("+---------------------------------------------+"),

    ?ELog("creating (drop if exists) table ~s", [?TESTTABLE]),
    TmpDropStmt = OciSession:prep_sql(?DROP),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, TmpDropStmt),
    case TmpDropStmt:exec_stmt() of
        {error, _} -> ok; % If table doesn't exists the handle isn't valid
        _ -> ?assertEqual(ok, TmpDropStmt:close())
    end,
    StmtCreate = OciSession:prep_sql(?CREATE),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, StmtCreate),
    ?assertEqual({executed, 0}, StmtCreate:exec_stmt()),
    ?assertEqual(ok, StmtCreate:close()),

    ?ELog("dropping table ~s", [?TESTTABLE]),
    DropStmt = OciSession:prep_sql(?DROP),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, DropStmt),
    ?assertEqual({executed,0}, DropStmt:exec_stmt()),
    ?assertEqual(ok, DropStmt:close()).

bad_sql_connection_reuse(#{ocisession := OciSession}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|           bad_sql_connection_reuse          |"),
    ?ELog("+---------------------------------------------+"),
    BadSelect = <<"select 'abc from dual">>,
    ?assertMatch({error, {1756, _}}, OciSession:prep_sql(BadSelect)),
    GoodSelect = <<"select 'abc' from dual">>,
    SelStmt = OciSession:prep_sql(GoodSelect),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, SelStmt),
    ?assertMatch({cols, [{<<"'ABC'">>,'SQLT_AFC',_,0,0}]}, SelStmt:exec_stmt()),
    ?assertEqual({{rows, [[<<"abc">>]]}, true}, SelStmt:fetch_rows(2)),
    ?assertEqual(ok, SelStmt:close()).


insert_select_update(#{ocisession := OciSession}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|            insert_select_update             |"),
    ?ELog("+---------------------------------------------+"),
    RowCount = 6,

    flush_table(OciSession),

    ?ELog("~s", [binary_to_list(?INSERT)]),
    BoundInsStmt = OciSession:prep_sql(?INSERT),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, BoundInsStmt),
    BoundInsStmtRes = BoundInsStmt:bind_vars(?BIND_LIST),
    ?assertMatch(ok, BoundInsStmtRes),
    %pkey,publisher,rank,hero,reality,votes,createdate,chapters,votes_first_rank
    {rowids, RowIds1} = BoundInsStmt:exec_stmt(
        [{ I                                                                                % pkey
         , unicode:characters_to_binary(["_püèr_",integer_to_list(I),"_"])                % publisher
         , I+I/2                                                                            % rank
         , 1.0e-307                                                                         % hero
         , list_to_binary([rand:uniform(255) || _I <- lists:seq(1,rand:uniform(5)+5)])  % reality
         , I                                                                                % votes
         , oci_util:edatetime_to_ora(os:timestamp())                                        % createdate
         , 9.999999350456404e-39                                                            % chapters
         , I                                                                                % votes_first_rank
         } || I <- lists:seq(1, RowCount div 2)]
    ),
    ?ELog("Bound insert statement reuse"),
    {rowids, RowIds2} = BoundInsStmt:exec_stmt(
        [{ I                                                                                % pkey
         , unicode:characters_to_binary(["_püèr_",integer_to_list(I),"_"])                % publisher
         , I+I/2                                                                            % rank
         , 1.0e-307                                                                         % hero
         , list_to_binary([rand:uniform(255) || _I <- lists:seq(1,rand:uniform(5)+5)])  % reality
         , I                                                                                % votes
         , oci_util:edatetime_to_ora(os:timestamp())                                        % createdate
         , 9.999999350456404e-39                                                            % chapters
         , I                                                                                % votes_first_rank
         } || I <- lists:seq((RowCount div 2) + 1, RowCount)]
    ),
    RowIds = RowIds1 ++ RowIds2,
    ?assertMatch(RowCount, length(RowIds)),
    ?assertEqual(ok, BoundInsStmt:close()),

    ?ELog("~s", [binary_to_list(?SELECT_WITH_ROWID)]),
    SelStmt = OciSession:prep_sql(?SELECT_WITH_ROWID),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, SelStmt),
    {cols, Cols} = SelStmt:exec_stmt(),
    ?ELog("selected columns ~p from table ~s", [Cols, ?TESTTABLE]),
    ?assertEqual(10, length(Cols)),
    {{rows, Rows0}, false} = SelStmt:fetch_rows(2),
    {{rows, Rows1}, false} = SelStmt:fetch_rows(2),
    {{rows, Rows2}, true} = SelStmt:fetch_rows(3),
    ?assertEqual(ok, SelStmt:close()),

    Rows = lists:merge([Rows0, Rows1, Rows2]),
    %?ELog("Got rows~n~p", [
    %    [
    %        begin
    %        [Rowid
    %        , Pkey
    %        , Publisher
    %        , Rank
    %        , Hero
    %        , Reality
    %        , Votes
    %        , Createdate
    %        , Chapters
    %        , Votes_first_rank] = R,
    %        [Rowid
    %        , oci_util:oranumber_decode(Pkey)
    %        , Publisher
    %        , oci_util:oranumber_decode(Rank)
    %        , Hero
    %        , Reality
    %        , oci_util:oranumber_decode(Votes)
    %        , oci_util:oradate_to_str(Createdate)
    %        , oci_util:oranumber_decode(Chapters)
    %        , oci_util:oranumber_decode(Votes_first_rank)]
    %        end
    %    || R <- Rows]
    %]),
    %RowIDs = [R || [R|_] <- Rows],
    [begin
        ?assertEqual(1.0e-307, Hero),
        ?assertEqual(9.999999350456404e-39, Chapters),
        ?assertEqual(<< "_püèr_"/utf8 >>, binary:part(Publisher, 0, byte_size(<< "_püèr_"/utf8 >>)))
    end
    || [_, _, Publisher, _, Hero, _, _, _, Chapters, _] <- Rows],
    RowIDs = [R || [R|_] <- Rows],

    ?ELog("RowIds ~p", [RowIDs]),
    ?ELog("~s", [binary_to_list(?UPDATE)]),
    BoundUpdStmt = OciSession:prep_sql(?UPDATE),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, BoundUpdStmt),
    BoundUpdStmtRes = BoundUpdStmt:bind_vars(
                        lists:keyreplace(<<":votes">>, 1, ?UPDATE_BIND_LIST, {<<":votes">>, 'SQLT_INT'})),
    ?assertMatch(ok, BoundUpdStmtRes),
    ?assertMatch({rowids, _}, BoundUpdStmt:exec_stmt(
        [{ I                                                                 % pkey
         , unicode:characters_to_binary(["_Püèr_",integer_to_list(I),"_"]) % publisher
         , I+I/3                                                             % rank
         , I+I/50                                                            % hero
         , <<>> % deleting                                                   % reality
         , I+1                                                               % votes
         , oci_util:edatetime_to_ora(os:timestamp())                         % createdate
         , I*2+I/1000                                                        % chapters
         , I+1                                                               % votes_first_rank
         , Key
         } || {Key, I} <- lists:zip(RowIds1, lists:seq(1, RowCount div 2))]
    )),
    ?ELog("Bound update statement reuse"),
    ?assertMatch({rowids, _}, BoundUpdStmt:exec_stmt(
        [{ I                                                                 % pkey
         , unicode:characters_to_binary(["_Püèr_",integer_to_list(I),"_"]) % publisher
         , I+I/3                                                             % rank
         , I+I/50                                                            % hero
         , <<>> % deleting                                                   % reality
         , I+1                                                               % votes
         , oci_util:edatetime_to_ora(os:timestamp())                         % createdate
         , I*2+I/1000                                                        % chapters
         , I+1                                                               % votes_first_rank
         , Key
         } || {Key, I} <- lists:zip(RowIds2, lists:seq((RowCount div 2) + 1, RowCount))]
    )),
    ?assertEqual(ok, BoundUpdStmt:close()).

auto_rollback(#{ocisession := OciSession}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|                auto_rollback                |"),
    ?ELog("+---------------------------------------------+"),
    RowCount = 3,

    flush_table(OciSession),

    ?ELog("inserting into table ~s", [?TESTTABLE]),
    BoundInsStmt = OciSession:prep_sql(?INSERT),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, BoundInsStmt),
    BoundInsStmtRes = BoundInsStmt:bind_vars(?BIND_LIST),
    ?assertMatch(ok, BoundInsStmtRes),
    ?assertMatch({rowids, _},
    BoundInsStmt:exec_stmt(
        [{ I                                                                                % pkey
         , list_to_binary(["_publisher_",integer_to_list(I),"_"])                           % publisher
         , I+I/2                                                                            % rank
         , I+I/3                                                                            % hero
         , list_to_binary([rand:uniform(255) || _I <- lists:seq(1,rand:uniform(5)+5)])  % reality
         , I                                                                                % votes
         , oci_util:edatetime_to_ora(os:timestamp())                                        % createdate
         , I                                                                                % chapters
         , I                                                                                % votes_first_rank
         } || I <- lists:seq(1, RowCount)]
        , 1
    )),
    ?assertEqual(ok, BoundInsStmt:close()),

    ?ELog("selecting from table ~s", [?TESTTABLE]),
    SelStmt = OciSession:prep_sql(?SELECT_WITH_ROWID),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, SelStmt),
    {cols, Cols} = SelStmt:exec_stmt(),
    ?assertEqual(10, length(Cols)),
    {{rows, Rows}, false} = SelStmt:fetch_rows(RowCount),

    ?ELog("update in table ~s", [?TESTTABLE]),
    RowIDs = [R || [R|_] <- Rows],
    BoundUpdStmt = OciSession:prep_sql(?UPDATE),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, BoundUpdStmt),
    BoundUpdStmtRes = BoundUpdStmt:bind_vars(?UPDATE_BIND_LIST),
    ?assertMatch(ok, BoundUpdStmtRes),

    % Expected Invalid number Error (1722)
    ?assertMatch({error,{1722,_}}, BoundUpdStmt:exec_stmt(
        [{ I                                                                                % pkey
         , list_to_binary(["_Publisher_",integer_to_list(I),"_"])                           % publisher
         , I+I/3                                                                            % rank
         , I+I/2                                                                            % hero
         , list_to_binary([rand:uniform(255) || _I <- lists:seq(1,rand:uniform(5)+5)])  % reality
         , if I > (RowCount-2) -> <<"error">>; true -> integer_to_binary(I+1) end           % votes
         , oci_util:edatetime_to_ora(os:timestamp())                                        % createdate
         , I+2                                                                              % chapters
         , I+1                                                                              % votes_first_rank
         , Key
         } || {Key, I} <- lists:zip(RowIDs, lists:seq(1, length(RowIDs)))]
        , 1
    )),

    ?ELog("testing rollback table ~s", [?TESTTABLE]),
    ?assertEqual({cols, Cols}, SelStmt:exec_stmt()),
    ?assertEqual({{rows, Rows}, false}, SelStmt:fetch_rows(RowCount)),
    ?assertEqual(ok, SelStmt:close()).

commit_rollback(#{ocisession := OciSession}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|               commit_rollback               |"),
    ?ELog("+---------------------------------------------+"),
    RowCount = 3,

    flush_table(OciSession),

    ?ELog("inserting into table ~s", [?TESTTABLE]),
    BoundInsStmt = OciSession:prep_sql(?INSERT),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, BoundInsStmt),
    BoundInsStmtRes = BoundInsStmt:bind_vars(?BIND_LIST),
    ?assertMatch(ok, BoundInsStmtRes),
    ?assertMatch({rowids, _},
        BoundInsStmt:exec_stmt(
          [{ I                                                              % pkey
           , list_to_binary(["_publisher_",integer_to_list(I),"_"])         % publisher
           , I+I/2                                                          % rank
           , I+I/3                                                          % hero
           , list_to_binary([rand:uniform(255)
                             || _I <- lists:seq(1,rand:uniform(5)+5)])    % reality
           , I                                                              % votes
           , oci_util:edatetime_to_ora(os:timestamp())                      % createdate
           , I*2+I/1000                                                     % chapters
           , I                                                              % votes_first_rank
           } || I <- lists:seq(1, RowCount)]
          , 1
    )),
    ?assertEqual(ok, BoundInsStmt:close()),

    ?ELog("selecting from table ~s", [?TESTTABLE]),
    SelStmt = OciSession:prep_sql(?SELECT_WITH_ROWID),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, SelStmt),
    {cols, Cols} = SelStmt:exec_stmt(),
    ?assertEqual(10, length(Cols)),
    {{rows, Rows}, false} = SelStmt:fetch_rows(RowCount),
    ?assertEqual(RowCount, length(Rows)),

    ?ELog("update in table ~s", [?TESTTABLE]),
    RowIDs = [R || [R|_] <- Rows],
    ?ELog("rowids ~p", [RowIDs]),
    BoundUpdStmt = OciSession:prep_sql(?UPDATE),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, BoundUpdStmt),
    BoundUpdStmtRes = BoundUpdStmt:bind_vars(?UPDATE_BIND_LIST),
    ?assertMatch(ok, BoundUpdStmtRes),
    ?assertMatch({rowids, _},
        BoundUpdStmt:exec_stmt(
          [{ I                                                              % pkey
           , list_to_binary(["_Publisher_",integer_to_list(I),"_"])         % publisher
           , I+I/3                                                          % rank
           , I+I/2                                                          % hero
           , list_to_binary([rand:uniform(255)
                             || _I <- lists:seq(1,rand:uniform(5)+5)])    % reality
           , integer_to_binary(I+1)                                         % votes
           , oci_util:edatetime_to_ora(os:timestamp())                      % createdate
           , I+2                                                            % chapters
           , I+1                                                            % votes_first_rank
           , Key
           } || {Key, I} <- lists:zip(RowIDs, lists:seq(1, length(RowIDs)))]
          , -1
    )),

    ?assertMatch(ok, BoundUpdStmt:close()),

    ?ELog("testing rollback table ~s", [?TESTTABLE]),
    ?assertEqual(ok, OciSession:rollback()),
    ?assertEqual({cols, Cols}, SelStmt:exec_stmt()),
    {{rows, NewRows}, false} = SelStmt:fetch_rows(RowCount),
    ?assertEqual(lists:sort(Rows), lists:sort(NewRows)),
    ?assertEqual(ok, SelStmt:close()).

asc_desc(#{ocisession := OciSession}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|                  asc_desc                   |"),
    ?ELog("+---------------------------------------------+"),
    RowCount = 10,

    flush_table(OciSession),

    ?ELog("inserting into table ~s", [?TESTTABLE]),
    BoundInsStmt = OciSession:prep_sql(?INSERT),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, BoundInsStmt),
    ?assertMatch(ok, BoundInsStmt:bind_vars(?BIND_LIST)),
    ?assertMatch({rowids, _}, BoundInsStmt:exec_stmt(
        [{ I                                                                                % pkey
         , list_to_binary(["_publisher_",integer_to_list(I),"_"])                           % publisher
         , I+I/2                                                                            % rank
         , I+I/3                                                                            % hero
         , list_to_binary([rand:uniform(255) || _I <- lists:seq(1,rand:uniform(5)+5)])  % reality
         , I                                                                                % votes
         , oci_util:edatetime_to_ora(os:timestamp())                                        % createdate
         , I*2+I/1000                                                                       % chapters
         , I                                                                                % votes_first_rank
         } || I <- lists:seq(1, RowCount)]
        , 1
    )),
    ?assertEqual(ok, BoundInsStmt:close()),

    ?ELog("selecting from table ~s", [?TESTTABLE]),
    SelStmt1 = OciSession:prep_sql(?SELECT_ROWID_ASC),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, SelStmt1),
    SelStmt2 = OciSession:prep_sql(?SELECT_ROWID_DESC),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, SelStmt2),
    ?assertEqual(SelStmt1:exec_stmt(), SelStmt2:exec_stmt()),

    {{rows, Rows11}, false} = SelStmt1:fetch_rows(5),
    {{rows, Rows12}, false} = SelStmt1:fetch_rows(5),
    {{rows, []}, true} = SelStmt1:fetch_rows(1),
    Rows1 = Rows11++Rows12,
    ?assertEqual(RowCount, length(Rows1)),

    {{rows, Rows21}, false} = SelStmt2:fetch_rows(5),
    {{rows, Rows22}, false} = SelStmt2:fetch_rows(5),
    {{rows, []}, true} = SelStmt2:fetch_rows(1),
    Rows2 = Rows21++Rows22,
    ?assertEqual(RowCount, length(Rows2)),

    ?ELog("Got rows asc ~p~n desc ~p", [Rows1, Rows2]),

    ?assertEqual(Rows1, lists:reverse(Rows2)),

    ?assertEqual(ok, SelStmt1:close()),
    ?assertEqual(ok, SelStmt2:close()).

describe(#{ocisession := OciSession}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|                 describe                    |"),
    ?ELog("+---------------------------------------------+"),

    flush_table(OciSession),

    ?ELog("describing table ~s", [?TESTTABLE]),
    {ok, Descs} = OciSession:describe(list_to_binary(?TESTTABLE), 'OCI_PTYPE_TABLE'),
    ?assertEqual(9, length(Descs)),
    ?ELog("table ~s has ~p", [?TESTTABLE, Descs]).

function(#{ocisession := OciSession}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|                function                     |"),
    ?ELog("+---------------------------------------------+"),

    CreateFunction = OciSession:prep_sql(<<"
        create or replace function "
        ?TESTFUNCTION
        "(sal in number, com in number)
            return number is
        begin
            return ((sal*12)+(sal*12*nvl(com,0)));
        end;
    ">>),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, CreateFunction),
    ?assertEqual({executed, 0}, CreateFunction:exec_stmt()),
    ?assertEqual(ok, CreateFunction:close()),

    SelectStmt = OciSession:prep_sql(<<"select "?TESTFUNCTION"(10,30) from dual">>),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, SelectStmt),
    {cols, [Col|_]} = SelectStmt:exec_stmt(),
    ?assertEqual(<<?TESTFUNCTION"(10,30)">>, element(1, Col)),
    {{rows, [[F|_]|_]}, true} = SelectStmt:fetch_rows(2),
    ?assertEqual(<<3,194,38,21,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0>>, F),
    ?assertEqual(ok, SelectStmt:close()),

    SelectBoundStmt = OciSession:prep_sql(<<"select "?TESTFUNCTION"(:SAL,:COM) from dual">>),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, SelectBoundStmt),
    ?assertMatch(ok, SelectBoundStmt:bind_vars([{<<":SAL">>, 'SQLT_INT'}, {<<":COM">>, 'SQLT_INT'}])),
    {cols, [Col2|_]} = SelectBoundStmt:exec_stmt([{10, 30}], 1),
    ?assertEqual(<<?TESTFUNCTION"(:SAL,:COM)">>, element(1, Col2)),
    ?assertMatch({{rows, [[F|_]|_]}, true}, SelectBoundStmt:fetch_rows(2)),
    ?ELog("Col ~p", [Col]),
    ?assertEqual(ok, SelectBoundStmt:close()),

    % Drop function
    DropFunStmt = OciSession:prep_sql(<<"drop function "?TESTFUNCTION>>),
    ?assertEqual({executed, 0}, DropFunStmt:exec_stmt()),
    ?assertEqual(ok, DropFunStmt:close()).

procedure_scalar(#{ocisession := OciSession}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|             procedure_scalar                |"),
    ?ELog("+---------------------------------------------+"),

    CreateProcedure = OciSession:prep_sql(<<"
        create or replace procedure "
        ?TESTPROCEDURE
        "(p_first in number, p_second in out varchar2, p_result out number)
        is
        begin
            p_result := p_first + to_number(p_second);
            p_second := 'The sum is ' || to_char(p_result);
        end "?TESTPROCEDURE";
        ">>),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, CreateProcedure),
    ?assertEqual({executed, 0}, CreateProcedure:exec_stmt()),
    ?assertEqual(ok, CreateProcedure:close()),

    ExecStmt = OciSession:prep_sql(<<"begin "?TESTPROCEDURE"(:p_first,:p_second,:p_result); end;">>),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, ExecStmt),
    ?assertMatch(ok, ExecStmt:bind_vars([ {<<":p_first">>, in, 'SQLT_INT'}
                                        , {<<":p_second">>, inout, 'SQLT_CHR'}
                                        , {<<":p_result">>, out, 'SQLT_INT'}])),
    ?assertEqual({executed, 1,
                  [{<<":p_second">>,<<"The sum is 51">>},
                   {<<":p_result">>,51}]},
                 ExecStmt:exec_stmt([{50, <<"1             ">>, 3}], 1)),
    ?assertEqual({executed, 1,
                  [{<<":p_second">>,<<"The sum is 6">>},
                   {<<":p_result">>,6}]}, ExecStmt:exec_stmt([{5, <<"1             ">>, 3}], 1)),
    ?assertEqual(ok, ExecStmt:close()),

    ExecStmt1 = OciSession:prep_sql(<<"call "?TESTPROCEDURE"(:p_first,:p_second,:p_result)">>),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, ExecStmt1),
    ?assertMatch(ok, ExecStmt1:bind_vars(
                       [ {<<":p_first">>, in, 'SQLT_INT'}, {<<":p_second">>, inout, 'SQLT_CHR'},
                         {<<":p_result">>, out, 'SQLT_INT'}])),
    ?assertEqual({executed, 0,
                  [{<<":p_second">>,<<"The sum is 52">>}, {<<":p_result">>,52}]},
                 ExecStmt1:exec_stmt([{50, <<"2             ">>, 3}], 1)),
    ?assertEqual({executed, 0,
                  [{<<":p_second">>,<<"The sum is 7">>},
                   {<<":p_result">>,7}]}, ExecStmt1:exec_stmt([{5, <<"2             ">>, 3}], 1)),
    ?assertEqual(ok, ExecStmt1:close()),

    ExecStmt2 = OciSession:prep_sql(<<"declare begin "?TESTPROCEDURE"(:p_first,:p_second,:p_result); end;">>),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, ExecStmt2),
    ?assertMatch(ok, ExecStmt2:bind_vars([ {<<":p_first">>, in, 'SQLT_INT'}
                                        , {<<":p_second">>, inout, 'SQLT_CHR'}
                                        , {<<":p_result">>, out, 'SQLT_INT'}])),
    ?assertEqual({executed, 1,
                  [{<<":p_second">>,<<"The sum is 53">>},
                   {<<":p_result">>,53}]}, ExecStmt2:exec_stmt([{50, <<"3             ">>, 3}], 1)),
    ?assertEqual({executed, 1,
                  [{<<":p_second">>,<<"The sum is 8">>},
                   {<<":p_result">>,8}]}, ExecStmt2:exec_stmt([{5, <<"3             ">>, 3}], 1)),
    ?assertEqual(ok, ExecStmt2:close()),

    % Drop procedure
    DropProcStmt = OciSession:prep_sql(<<"drop procedure "?TESTPROCEDURE>>),
    ?assertEqual({executed, 0}, DropProcStmt:exec_stmt()),
    ?assertEqual(ok, DropProcStmt:close()).

procedure_cur(#{ocisession := OciSession}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|               procedure_cur                 |"),
    ?ELog("+---------------------------------------------+"),

    RowCount = 10,

    flush_table(OciSession),

    ?ELog("inserting into table ~s", [?TESTTABLE]),
    BoundInsStmt = OciSession:prep_sql(?INSERT),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, BoundInsStmt),
    ?assertMatch(ok, BoundInsStmt:bind_vars(?BIND_LIST)),
    ?assertMatch({rowids, _}, BoundInsStmt:exec_stmt(
        [{ I                                                                                % pkey
         , list_to_binary(["_publisher_",integer_to_list(I),"_"])                           % publisher
         , I+I/2                                                                            % rank
         , I+I/3                                                                            % hero
         , list_to_binary([rand:uniform(255) || _I <- lists:seq(1,rand:uniform(5)+5)])  % reality
         , I                                                                                % votes
         , oci_util:edatetime_to_ora(os:timestamp())                                        % createdate
         , I*2+I/1000                                                                       % chapters
         , I                                                                                % votes_first_rank
         } || I <- lists:seq(1, RowCount)]
        , 1
    )),
    ?assertEqual(ok, BoundInsStmt:close()),

    CreateProcedure = OciSession:prep_sql(<<"
        create or replace procedure "
        ?TESTPROCEDURE
        "(p_cur out sys_refcursor)
        is
        begin
            open p_cur for select * from "?TESTTABLE";
        end "?TESTPROCEDURE";
        ">>),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, CreateProcedure),
    ?assertEqual({executed, 0}, CreateProcedure:exec_stmt()),
    ?assertEqual(ok, CreateProcedure:close()),

    ExecStmt = OciSession:prep_sql(<<"begin "?TESTPROCEDURE"(:cursor); end;">>),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, ExecStmt),
    ?assertMatch(ok, ExecStmt:bind_vars([{<<":cursor">>, out, 'SQLT_RSET'}])),
    {executed, 1, [{<<":cursor">>, CurStmt}]} = ExecStmt:exec_stmt(),
    {cols, _Cols} = CurStmt:exec_stmt(),
    {{rows, Rows}, true} = CurStmt:fetch_rows(RowCount+1),
    ?assertEqual(RowCount, length(Rows)),
    ?assertEqual(ok, CurStmt:close()),
    ?assertEqual(ok, ExecStmt:close()),

    % Drop procedure
    DropProcStmt = OciSession:prep_sql(<<"drop procedure "?TESTPROCEDURE>>),
    ?assertEqual({executed, 0}, DropProcStmt:exec_stmt()),
    ?assertEqual(ok, DropProcStmt:close()).

timestamp_interval_datatypes(#{ocisession := OciSession}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|       timestamp_interval_datatypes          |"),
    ?ELog("+---------------------------------------------+"),

    CreateSql = <<
        "create table "?TESTTABLE" ("
            "name varchar(30), "
            "dat DATE DEFAULT (sysdate), "
            "ts TIMESTAMP DEFAULT (systimestamp), "
            "tstz TIMESTAMP WITH TIME ZONE DEFAULT (systimestamp), "
            "tsltz TIMESTAMP WITH LOCAL TIME ZONE DEFAULT (systimestamp), "
            "iym INTERVAL YEAR(3) TO MONTH DEFAULT '234-2', "
            "ids INTERVAL DAY TO SECOND(3) DEFAULT '4 5:12:10.222')"
    >>,
    InsertNameSql = <<"insert into "?TESTTABLE" (name) values (:name)">>,
    InsertSql = <<"insert into "?TESTTABLE" (name, dat, ts, tstz, tsltz, iym, ids) "
                  "values (:name, :dat, :ts, :tstz, :tsltz, :iym, :ids)">>,
    InsertBindSpec = [ {<<":name">>, 'SQLT_CHR'}
                     , {<<":dat">>, 'SQLT_DAT'}
                     , {<<":ts">>, 'SQLT_TIMESTAMP'}
                     , {<<":tstz">>, 'SQLT_TIMESTAMP_TZ'}
                     , {<<":tsltz">>, 'SQLT_TIMESTAMP_LTZ'}
                     , {<<":iym">>, 'SQLT_INTERVAL_YM'}
                     , {<<":ids">>, 'SQLT_INTERVAL_DS'}],
    SelectSql = <<"select * from "?TESTTABLE"">>,

    DropStmt = OciSession:prep_sql(?DROP),
    DropStmt:exec_stmt(),
    DropStmt:close(),

    CreateStmt = OciSession:prep_sql(CreateSql),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, CreateStmt),
    ?assertEqual({executed, 0}, CreateStmt:exec_stmt()),
    ?assertEqual(ok, CreateStmt:close()),

    BoundInsStmt = OciSession:prep_sql(InsertNameSql),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, BoundInsStmt),
    ?assertMatch(ok, BoundInsStmt:bind_vars([{<<":name">>, 'SQLT_CHR'}])),
    ?assertMatch({rowids, _}, BoundInsStmt:exec_stmt(
        [{list_to_binary(io_lib:format("'~s'", [D]))}
         || D <- ["test1", "test2", "test3", "test4"]])),
    ?assertMatch(ok, BoundInsStmt:close()),

    SelectStmt = OciSession:prep_sql(SelectSql),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, SelectStmt),
    ?assertMatch({cols, [{<<"NAME">>,'SQLT_CHR',_,0,0}
                        ,{<<"DAT">>,'SQLT_DAT',7,0,0}
                        ,{<<"TS">>,'SQLT_TIMESTAMP',11,0,6}
                        ,{<<"TSTZ">>,'SQLT_TIMESTAMP_TZ',13,0,6}
                        ,{<<"TSLTZ">>,'SQLT_TIMESTAMP_LTZ',11,0,6}
                        ,{<<"IYM">>,'SQLT_INTERVAL_YM',5,3,0}
                        ,{<<"IDS">>,'SQLT_INTERVAL_DS',11,2,3}]}
                 , SelectStmt:exec_stmt()),
    RowRet = SelectStmt:fetch_rows(5),
    ?assertEqual(ok, SelectStmt:close()),

    ?assertMatch({{rows, _}, true}, RowRet),
    {{rows, Rows}, true} = RowRet,
    NewRows =
    [begin
         {{C2Y,C2M,C2D}, {C2H,C2Min,C2S}} = oci_util:from_dts(C2),
         {{C3Y,C3M,C3D}, {C3H,C3Min,C3S}, C3Ns} = oci_util:from_dts(C3),
         {{C4Y,C4M,C4D}, {C4H,C4Min,C4S}, C4Ns, {C4TzH,C4TzM}} = oci_util:from_dts(C4),
         {{C5Y,C5M,C5D}, {C5H,C5Min,C5S}, C5Ns} = oci_util:from_dts(C5),
         {C6Y,C6M} = oci_util:from_intv(C6),
         {C7D,C7H,C7M,C7S,C7Ns} = oci_util:from_intv(C7),
         {list_to_binary([C1, "_1"])
          , oci_util:to_dts({{C2Y+1,C2M+1,C2D+1}, {C2H+1,C2Min+1,C2S+1}})
          , oci_util:to_dts({{C3Y+1,C3M+1,C3D+1}, {C3H+1,C3Min+1,C3S+1}, C3Ns+1})
          , oci_util:to_dts({{C4Y+1,C4M+1,C4D+1}, {C4H+1,C4Min+1,C4S+1}, C4Ns+1, {C4TzH+1,C4TzM+1}})
          , oci_util:to_dts({{C5Y+1,C5M+1,C5D+1}, {C5H+1,C5Min+1,C5S+1}, C5Ns+1})
          , oci_util:to_intv({C6Y+1,C6M+1})
          , oci_util:to_intv({C7D+1,C7H+1,C7M+1,C7S+1,C7Ns+1})}
     end
     || [C1, C2, C3, C4, C5, C6, C7] <- Rows],
    BoundAllInsStmt = OciSession:prep_sql(InsertSql),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, BoundAllInsStmt),
    ?assertMatch(ok, BoundAllInsStmt:bind_vars(InsertBindSpec)),
    Inserted = BoundAllInsStmt:exec_stmt(NewRows),
    ?assertMatch({rowids, _}, Inserted),
    {rowids, RowIds} = Inserted,
    ?assertEqual(length(NewRows), length(RowIds)),
    ?assertMatch(ok, BoundAllInsStmt:close()),

    DropStmtFinal = OciSession:prep_sql(?DROP),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, DropStmtFinal),
    ?assertEqual({executed, 0}, DropStmtFinal:exec_stmt()),
    ?assertEqual(ok, DropStmtFinal:close()),
    ok.

stmt_reuse_onerror(#{ocisession := OciSession}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|             stmt_reuse_onerror              |"),
    ?ELog("+---------------------------------------------+"),

    CreateSql = <<"create table "?TESTTABLE" (unique_num number not null primary key)">>,
    InsertSql = <<"insert into "?TESTTABLE" (unique_num) values (:unique_num)">>,

    DropStmt = OciSession:prep_sql(?DROP),
    DropStmt:exec_stmt(),
    DropStmt:close(),

    CreateStmt = OciSession:prep_sql(CreateSql),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, CreateStmt),
    ?assertEqual({executed, 0}, CreateStmt:exec_stmt()),
    ?assertEqual(ok, CreateStmt:close()),

    BoundInsStmt = OciSession:prep_sql(InsertSql),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, BoundInsStmt),
    ?assertMatch(ok, BoundInsStmt:bind_vars([{<<":unique_num">>, 'SQLT_INT'}])),
    ?assertMatch({rowids, _}, BoundInsStmt:exec_stmt([{1}])),
    ?assertMatch({error,{1,<<"ORA-00001",_/binary>>}}, BoundInsStmt:exec_stmt([{1}])),
    ?assertMatch({rowids, _}, BoundInsStmt:exec_stmt([{2}])),
    ?assertMatch({error,{1,<<"ORA-00001",_/binary>>}}, BoundInsStmt:exec_stmt([{2}])),
    ?assertMatch(ok, BoundInsStmt:close()),

    DropStmtFinal = OciSession:prep_sql(?DROP),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, DropStmtFinal),
    ?assertEqual({executed, 0}, DropStmtFinal:exec_stmt()),
    ?assertEqual(ok, DropStmtFinal:close()),
    ok.

multiple_bind_reuse(#{ocisession := OciSession}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|             multiple_bind_reuse             |"),
    ?ELog("+---------------------------------------------+"),

    Cols = [lists:flatten(io_lib:format("col~p", [I]))
            || I <- lists:seq(1, 10)],
    BindVarCols = [io_lib:format(":P_~s", [C]) || C <- Cols],
    CreateSql = <<"create table "?TESTTABLE" (",
                  (list_to_binary(
                     string:join(
                       [io_lib:format("~s varchar(30)", [C]) || C <- Cols],
                       ", ")))/binary,
                  ")">>,
    InsertSql = <<"insert into "?TESTTABLE" (",
                    (list_to_binary(
                     string:join(
                       [io_lib:format("~s", [C]) || C <- Cols],
                       ", ")))/binary,
                  ") values (",
                  (list_to_binary(string:join(BindVarCols,", ")))/binary,")">>,
    SelectSql = <<"select * from "?TESTTABLE"">>,
    InsertBindVars = [{list_to_binary(BC), 'SQLT_CHR'} || BC <- BindVarCols],

    DropStmt = OciSession:prep_sql(?DROP),
    DropStmt:exec_stmt(),
    DropStmt:close(),

    Data = [list_to_tuple([lists:nth(rand:uniform(3),
                                     [<<"">>, <<"big">>, <<"small">>])
                           || _ <- Cols]) || _ <- lists:seq(1, 10)],

    CreateStmt = OciSession:prep_sql(CreateSql),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, CreateStmt),
    ?assertEqual({executed, 0}, CreateStmt:exec_stmt()),
    ?assertEqual(ok, CreateStmt:close()),

    BoundInsStmt = OciSession:prep_sql(InsertSql),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, BoundInsStmt),
    ?assertMatch(ok, BoundInsStmt:bind_vars(InsertBindVars)),
    [?assertMatch({rowids, _}, BoundInsStmt:exec_stmt([R])) || R <- Data],

    SelectStmt = OciSession:prep_sql(SelectSql),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, SelectStmt),
    ?assertEqual({cols, [{list_to_binary(string:to_upper(C)),'SQLT_CHR',60,0,0}
                        || C <- Cols]},
                 SelectStmt:exec_stmt()),
    {{rows, Rows}, true} = SelectStmt:fetch_rows(length(Data)+1),
    {Error, _, _} =
    lists:foldl(fun(_I, {Flag, [ID|Insert], [ID|Select]}) ->
                        %% ?debugFmt("~p. expected ~p", [I, ID]),
                        %% ?debugFmt("~p. value    ~p", [I, ID]),
                        {Flag, Insert, Select};
                   (I, {_, [ID|Insert], [SD|Select]}) ->
                        ?debugFmt("~p. expected ~p", [I, ID]),
                        ?debugFmt("~p. value    ~p", [I, SD]),
                        {true, Insert, Select}
                end, {false, Data, [list_to_tuple(R) || R <- Rows]},
                lists:seq(1, length(Data))),
    ?assertEqual(false, Error),
    ?assertEqual(ok, SelectStmt:close()),

    ?assertMatch(ok, BoundInsStmt:close()),

    DropStmtFinal = OciSession:prep_sql(?DROP),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, DropStmtFinal),
    ?assertEqual({executed, 0}, DropStmtFinal:exec_stmt()),
    ?assertEqual(ok, DropStmtFinal:close()),
    ok.


-define(current_pool_session_ids(__OciSession),
        (fun(OciSess) ->
                 Stmt = OciSess:prep_sql(?SESSSQL),
                 ?assertMatch({cols, _}, Stmt:exec_stmt()),
                 {{rows, CurSessions}, true} = Stmt:fetch_rows(10000),
                 ?assertEqual(ok, Stmt:close()),
                 CurSessions
         end)(__OciSession)).

-define(kill_session(__OciSession, __SessionToKill),
        (fun(OciSessKS, Sess2Kill) ->
                 StmtKS = OciSessKS:prep_sql(
                            <<"alter system kill session '", Sess2Kill/binary,
                              "' immediate">>),
                 case StmtKS:exec_stmt() of
                     {error,{30, _}} -> ok;
                     {error,{31, _}} -> ok;
                     {executed, 0} -> ?ELog("~p closed", [Sess2Kill])
                 end,
                 ?assertEqual(ok, StmtKS:close())
         end)(__OciSession, __SessionToKill)).

check_ping(#{ocisession := OciSession, conf := #{tns := Tns, user := User, password := Pswd}}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|                 check_ping                  |"),
    ?ELog("+---------------------------------------------+"),
    SessionsBefore = ?current_pool_session_ids(OciSession),
    %% Connection with ping timeout set to 1 second
    PingOciPort = erloci:new([{logging, true}, {ping_timeout, 1000},
                              {env, [{"NLS_LANG", "GERMAN_SWITZERLAND.AL32UTF8"}]}]),
    PingOciSession = PingOciPort:get_session(Tns, User, Pswd),
    SessionsAfter = ?current_pool_session_ids(OciSession),
    [PingSession | _] = lists:flatten(SessionsAfter) -- lists:flatten(SessionsBefore),
    ?assertEqual(pong, PingOciSession:ping()),
    ?assertEqual(ok, ?kill_session(OciSession, PingSession)),
    ?debugMsg("sleeping for 2 seconds so that ping would realize the session is dead"),
    timer:sleep(2000),
    ?assertEqual(pang, PingOciSession:ping()),
    PingOciPort:close().

check_session_without_ping(#{ocisession := OciSession,
                             conf := #{tns := Tns, user := User, password := Pswd}}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|         check_session_without_ping          |"),
    ?ELog("+---------------------------------------------+"),
    SessionsBefore = ?current_pool_session_ids(OciSession),
    Opts = [{logging, true}, {env, [{"NLS_LANG", "GERMAN_SWITZERLAND.AL32UTF8"}]}],
    NoPingOciPort = erloci:new(Opts),
    NoPingOciSession = NoPingOciPort:get_session(Tns, User, Pswd),
    SelStmt1 = NoPingOciSession:prep_sql(<<"select 4+4 from dual">>),
    SessionsAfter = ?current_pool_session_ids(OciSession),
    ?assertMatch({cols, _}, SelStmt1:exec_stmt()),
    [NoPingSession | _] = lists:flatten(SessionsAfter) -- lists:flatten(SessionsBefore),
    ?assertEqual(ok, ?kill_session(OciSession, NoPingSession)),
    ?assertMatch({error, {3113, _}}, SelStmt1:exec_stmt()),
    NoPingOciPort:close().

check_session_with_ping(#{ocisession := OciSession, conf := #{tns := Tns, user := User, password := Pswd}}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|           check_session_with_ping           |"),
    ?ELog("+---------------------------------------------+"),
    SessionsBefore = ?current_pool_session_ids(OciSession),
    %% Connection with ping timeout set to 1 second
    Opts = [{logging, true}, {ping_timeout, 1000}, {env, [{"NLS_LANG", "GERMAN_SWITZERLAND.AL32UTF8"}]}],
    PingOciPort = erloci:new(Opts),
    PingOciSession = PingOciPort:get_session(Tns, User, Pswd),
    SelStmt1 = PingOciSession:prep_sql(<<"select 4+4 from dual">>),
    SessionsAfter = ?current_pool_session_ids(OciSession),
    ?assertMatch({cols, _}, SelStmt1:exec_stmt()),
    [NoPingSession | _] = lists:flatten(SessionsAfter) -- lists:flatten(SessionsBefore),
    ?assertEqual(ok, ?kill_session(OciSession, NoPingSession)),
    timer:sleep(2000),
    ?assertMatch({'EXIT', {noproc, _}}, catch SelStmt1:exec_stmt()),
    PingOciPort:close().

urowid(#{ocisession := OciSession}) ->
    ?ELog("+---------------------------------------------+"),
    ?ELog("|                  urowid                     |"),
    ?ELog("+---------------------------------------------+"),

    CreateStmt = OciSession:prep_sql(
                   <<"create table "?TESTTABLE" ("
                       " c1 number,"
                       " c2 varchar2(3000),"
                       " primary key(c1, c2))"
                     " organization index">>),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, CreateStmt),
    ?assertEqual({executed, 0}, CreateStmt:exec_stmt()),
    ?assertEqual(ok, CreateStmt:close()),

    ?ELog("testing insert returns UROWID"),
    [begin
         StmtInsert = OciSession:prep_sql(
                        <<"insert into "?TESTTABLE" values(",
                          (integer_to_binary(I))/binary, ",'",
                          (list_to_binary(
                             lists:duplicate(crypto:rand_uniform(1000,3000), I))
                          )/binary, "')">>),
        ?assertMatch({?PORT_MODULE, statement, _, _, _}, StmtInsert),
        ?assertMatch({rowids, [_]}, StmtInsert:exec_stmt()),
        ?assertEqual(ok, StmtInsert:close())
     end || I <- lists:seq($0,$9)],

    ?ELog("testing select UROWID"),
    SelectStmt = OciSession:prep_sql(<<"select rowid, c1 from "?TESTTABLE>>),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, SelectStmt),
    ?assertMatch({cols, _}, SelectStmt:exec_stmt()),
    {{rows, Rows}, true} = SelectStmt:fetch_rows(100),
    ?assertEqual(ok, SelectStmt:close()),

    ?ELog("testing update UROWID"),
    BoundUpdStmt = OciSession:prep_sql(
                     <<"update "?TESTTABLE" set c1 = :p_c1"
                       " where "?TESTTABLE".rowid = :p_rowid">>),
    ?assertMatch(ok, BoundUpdStmt:bind_vars([{<<":p_c1">>, 'SQLT_INT'},
                                             {<<":p_rowid">>, 'SQLT_STR'}])),
    ?assertMatch({rowids, _},
                 BoundUpdStmt:exec_stmt(
                   [{$0 + $9 - list_to_integer(oci_util:from_num(C1)), RowId}
                    || [RowId, C1] <- Rows], -1)),
    ?assertMatch(ok, BoundUpdStmt:close()),

    DropStmtFinal = OciSession:prep_sql(?DROP),
    ?assertMatch({?PORT_MODULE, statement, _, _, _}, DropStmtFinal),
    ?assertEqual({executed, 0}, DropStmtFinal:exec_stmt()),
    ?assertEqual(ok, DropStmtFinal:close()),
    ok.
