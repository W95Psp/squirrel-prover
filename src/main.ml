(** Main module for the testing binary.
  * See the [Metabc] module for the prover. *)

open Logic

let () = Printexc.record_backtrace true

exception Parse_error of string

let parse_from_buf ?(test=false) ?(interactive=false) parse_fun lexbuf filename =
  try parse_fun Lexer.token lexbuf with
  | Parser.Error as e ->
    let error = Fmt.strf
        "@[Error in %s @,at line %d char %d @,\
         before %S.@]@."
        filename
        lexbuf.Lexing.lex_curr_p.Lexing.pos_lnum
        (lexbuf.Lexing.lex_curr_p.Lexing.pos_cnum -
         lexbuf.Lexing.lex_curr_p.Lexing.pos_bol)
        (Lexing.lexeme lexbuf) in
    if interactive then
      raise @@ Parse_error error
    else if test then
      raise e
    else
      begin
        Fmt.pr "%s" error;
        exit 1
      end
  | Failure s ->
    let error = Fmt.strf
        "@[Error in %s @,at line %d char %d @,\
         before %S: @,%s.@]@."
        filename
        lexbuf.Lexing.lex_curr_p.Lexing.pos_lnum
        (lexbuf.Lexing.lex_curr_p.Lexing.pos_cnum -
         lexbuf.Lexing.lex_curr_p.Lexing.pos_bol)
        (Lexing.lexeme lexbuf)
        s
    in
    if interactive then
      raise @@ Parse_error error
    else if test then
      raise @@ Failure error
    else
      Fmt.pr "%s" error;
    exit 1
  | e ->
    let error = Fmt.strf
        "%s@.
      @[Error in %s @,at line %d char %d @,\
         before %S: @,%s.@]@."
        (Printexc.get_backtrace ())
        filename
        lexbuf.Lexing.lex_curr_p.Lexing.pos_lnum
        (lexbuf.Lexing.lex_curr_p.Lexing.pos_cnum -
         lexbuf.Lexing.lex_curr_p.Lexing.pos_bol)
        (Lexing.lexeme lexbuf)
        (Printexc.to_string e)
    in
    if test || interactive then raise e else
      begin
        Fmt.pr "%s" error;
        exit 1
      end

let parse_theory_buf ?(test=false) lexbuf filename =
  Theory.initialize_symbols () ;
  Process.reset () ;
  parse_from_buf ~test:test Parser.theory lexbuf filename

let parse_interactive_buf ?(test=false) lexbuf filename =
  parse_from_buf ~test:test ~interactive:true Parser.interactive lexbuf filename

let parse_process string =
  let lexbuf = Lexing.from_string string in
  try
    Parser.top_process Lexer.token lexbuf
  with Parser.Error as e ->
    Format.printf
      "Cannot parse process before %S at position TODO.@."
      (Lexing.lexeme lexbuf) ;
    raise e

let parse_theory_test ?(test=false) filename =
  let lexbuf = Lexing.from_channel (Pervasives.open_in filename) in
  parse_theory_buf ~test lexbuf filename

let () =
  Checks.add_suite "Parsing" [
    "Null", `Quick, begin fun () ->
      ignore (parse_process "null")
    end ;
    "Simple", `Quick, begin fun () ->
      Channel.reset () ;
      Channel.declare "c" ;
      ignore (parse_process "in(c,x);out(c,x);null") ;
      ignore (parse_process "in(c,x);out(c,x)") ;
      Alcotest.check_raises "fails" Parser.Error
        (fun () -> ignore (parse_process "in(c,x) then null")) ;
      begin match parse_process "(in(c,x);out(c,x) | in(c,x))" with
        | Process.Parallel _ -> ()
        | _ -> assert false
      end ;
      ignore (parse_process "if u then if v then null else null else null") ;
      Channel.reset ()
    end ;
    "Pairs", `Quick, begin fun () ->
      Theory.initialize_symbols () ;
      Channel.declare "c" ;
      ignore (parse_process "in(c,x);out(c,<x,x>)")
    end ;
    "Facts", `Quick, begin fun () ->
      Theory.initialize_symbols () ;
      Theory.declare_abstract "p" [] Theory.Boolean ;
      Channel.declare "c" ;
      ignore (parse_process "if p && p() then out(c,ok)") ;
      ignore (parse_process "if p() = p then out(c,ok)")
    end
  ];;

let () =
  let test = true in
  Checks.add_suite "Models" [
    "Null model", `Quick, begin fun () ->
      parse_theory_test ~test "examples/null.mbc"
    end ;
    "Simple model", `Quick, begin fun () ->
      parse_theory_test ~test "examples/process.mbc"
    end ;
    "Name declaration", `Quick, begin fun () ->
      parse_theory_test ~test "examples/name.mbc"
    end ;
    "Pairs", `Quick, begin fun () ->
      parse_theory_test ~test "examples/pairs.mbc"
    end ;
    "Basic theory", `Quick, begin fun () ->
      parse_theory_test ~test "examples/theory.mbc"
    end ;
    "Multiple declarations", `Quick, begin fun () ->
      Alcotest.check_raises "fails"
        (Failure "multiple declarations")
        (fun () -> parse_theory_test ~test "examples/multiple.mbc")
    end ;
    "Block creation", `Quick, begin fun () ->
      parse_theory_test ~test "examples/blocks.mbc"
      (* TODO test resulting block structure *)
    end ;
    "Let in blocks", `Quick, begin fun () ->
      parse_theory_test ~test "examples/block_let.mbc"
      (* TODO test resulting block structure *)
    end ;
    "New in blocks", `Quick, begin fun () ->
      parse_theory_test ~test "examples/block_name.mbc"
      (* TODO test resulting block structure *)
    end ;
    "Find in blocks", `Quick, begin fun () ->
      parse_theory_test ~test "examples/block_find.mbc"
      (* TODO test resulting block structure *)
    end ;
    "Updates in blocks", `Quick, begin fun () ->
      parse_theory_test ~test "examples/block_set.mbc"
      (* TODO test resulting block structure *)
    end ;
    "LAK model", `Quick, begin fun () ->
      parse_theory_test ~test "examples/lak.mbc"
    end ;
    "LAK model, again", `Quick, begin fun () ->
      (* We do this again, on purpose, to check that all definitions
       * from the previous run are gone. The macros from Term used
       * to not be re-initialized. *)
      parse_theory_test ~test "examples/lak.mbc"
    end ;
    (* "Simple goal", `Quick, begin fun () ->
     *   parse_theory_test ~test "examples/simple_goal.mbc"
     * end ; *)
  ];;
