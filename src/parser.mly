%token <int> INT
%token <string> ID   /* general purpose identifier */
%token <string> PID  /* predicate identifier */
%token <string> BANG
%token AT
%token LPAREN RPAREN
%token LANGLE RANGLE
%token AND OR NOT TRUE FALSE
%token EQ NEQ GEQ LEQ COMMA SEMICOLON COLON PLUS MINUS XOR
%token LET IN IF THEN ELSE FIND SUCHTHAT
%token NEW OUT PARALLEL NULL
%token CHANNEL TERM PROCESS HASH AENC NAME ABSTRACT MUTABLE SYSTEM
%token INDEX MESSAGE BOOLEAN TIMESTAMP ARROW ASSIGN
%token EXISTS FORALL QUANTIF GOAL DARROW AXIOM
%token DOT
%token APPLY TO TRY CYCLE REPEAT NOSIMPL
%token PROOF QED UNDO
%token EOF

%token EMPTY_ELSE

%left XOR

%nonassoc EMPTY_ELSE
%nonassoc ELSE
%nonassoc QUANTIF
%right DARROW
%left OR
%left AND
%nonassoc NOT

%left PLUS
%nonassoc REPEAT
%left SEMICOLON
%nonassoc TRY
%nonassoc NOSIMPL

%start theory
%start top_process
%start interactive
%type <unit> theory
%type <Process.process> top_process
%type <Prover.parsed_input> interactive

%%

(* Terms *)

timestamp:
| ID term_list                   { Theory.make_term $1 $2 }

term:
| LPAREN term RPAREN             { $2 }
| ID term_list                   { Theory.make_term $1 $2 }
| ID term_list AT timestamp      { let ts = $4 in
                                   Theory.make_term ~at_ts:ts $1 $2 }
| LANGLE term COMMA term RANGLE  { Theory.make_pair $2 $4 }
| term XOR term                  { Theory.make_term "xor" [$1;$3] }

term_list:
|                                { [] }
| LPAREN RPAREN                  { [] }
| LPAREN term tm_list RPAREN     { $2::$3 }

tm_list:
|                                { [] }
| COMMA term tm_list             { $2::$3 }

(* Facts, aka booleans *)

ord:
| EQ                             { Bformula.Eq }
| NEQ                            { Bformula.Neq }
| LEQ                            { Bformula.Leq }
| LANGLE                         { Bformula.Lt }
| GEQ                            { Bformula.Geq }
| RANGLE                         { Bformula.Gt }

kind:
| INDEX                          { Vars.Index }
| MESSAGE                        { Vars.Message }
| BOOLEAN                        { Vars.Boolean }
| TIMESTAMP                      { Vars.Timestamp }

arg_list:
|                                { [] }
| ID COLON kind                  { [$1,$3] }
| ID COLON kind COMMA arg_list   { ($1,$3)::$5 }



formula:
| LPAREN formula RPAREN          { $2 }
| formula AND formula            { Formula.And ($1,$3) }
| formula OR formula             { Formula.Or ($1,$3) }
| formula DARROW formula         { Formula.Impl ($1,$3) }
| NOT formula                    { Formula.Not ($2) }
| FALSE                          { Formula.False }
| TRUE                           { Formula.True }
| term ord term                  { Formula.Atom (Theory.Compare ($2,$1,$3)) }
| PID term_list                  { Formula.Atom (Theory.make_term $1 $2) }
| EXISTS LPAREN vs=arg_list RPAREN COMMA f=formula %prec QUANTIF
                                 { Formula.Exists (vs,f)  }
| FORALL LPAREN vs=arg_list RPAREN COMMA f=formula %prec QUANTIF
                                 { Formula.ForAll (vs,f)  }

(* Processes *)

process:
| NULL                           { Process.Null }
| LPAREN processes RPAREN        { $2 }
| ID term_list                   { Process.Apply ($1,$2) }
| ID COLON process               { Process.Alias ($3,$1) }
| NEW ID SEMICOLON process       { Process.New ($2,$4) }
| IN LPAREN channel COMMA ID RPAREN process_cont
                                 { Process.In ($3,$5,$7) }
| OUT LPAREN channel COMMA term RPAREN process_cont
                                 { Process.Out ($3,$5,$7) }
| IF f=formula THEN process else_process
                                 { Process.Exists
                                     ([],Theory.formula_to_fact f,$4,$5) }
| FIND indices SUCHTHAT f=formula IN process else_process
                                 { Process.Exists
                                     ($2,Theory.formula_to_fact f,$6,$7) }
| LET ID EQ term IN process      { Process.Let ($2,$4,$6) }
| ID term_list ASSIGN term process_cont
                                 { let to_idx = function
                                     | Theory.Var x -> x
                                     | _ -> failwith "index variable expected"
                                   in
                                   let l = List.map to_idx $2 in
                                   Process.Set ($1,l,$4,$5) }
| BANG process                   { Process.Repl ($1,$2) }

processes:
| process                        { $1 }
| process PARALLEL processes     { Process.Parallel ($1,$3) }

process_cont:
|                                { Process.Null }
| SEMICOLON process              { $2 }

else_process:
| %prec EMPTY_ELSE               { Process.Null }
| ELSE process                   { $2 }

channel:
| ID                             { try Channel.of_string $1 with Not_found ->
                                     failwith "unknown channel" }

indices:
| ID                             { [$1] }
| ID COMMA indices               { $1::$3 }

opt_arg_list:
| LPAREN arg_list RPAREN         { $2 }
|                                { [] }


name_type:
| MESSAGE                        { 0 }
| INDEX ARROW name_type          { 1+$3 }

msg_or_bool:
| MESSAGE                        { Vars.Message }
| BOOLEAN                        { Vars.Boolean }

state_type:
| msg_or_bool                    { 0, $1 }
| INDEX ARROW state_type         { let n,k = $3 in n+1,k }

abs_type:
| msg_or_bool                    { [],$1 }
| msg_or_bool ARROW abs_type     { let l,r = $3 in $1::l,r }

declaration:
| HASH ID                        { Theory.declare_hash $2 }
| AENC ID                        { Theory.declare_aenc $2 }
| NAME ID COLON name_type        { Theory.declare_name $2 $4 }
| ABSTRACT ID COLON abs_type     { let l,r = $4 in
                                   Theory.declare_abstract $2 l r }
| MUTABLE ID COLON state_type    { Theory.declare_state $2 (fst $4) (snd $4) }
| CHANNEL ID                     { Channel.declare $2 }
| TERM ID opt_arg_list COLON msg_or_bool EQ term
                                 { Theory.declare_macro $2 $3 $5 $7 }
| PROCESS ID opt_arg_list EQ process
                                 { Process.declare $2 $3 $5 }
| AXIOM f=formula		         { Prover.add_proved_goal
                                     ("unnamed_goal", Prover.make_goal f) }
| AXIOM i=ID COLON f=formula     { Prover.add_proved_goal
                                     (i, Prover.make_goal f) }

tactic_params:
|                               { [] }
| t=term                        { [t] }
| t=term COMMA ts=tactic_params { t::ts }

tac:
  | LPAREN t=tac RPAREN               { t }
  | l=tac SEMICOLON r=tac             { Prover.AST.AndThen [l;r] }
  | l=tac PLUS r=tac                  { Prover.AST.OrElse [l;r] }
  | TRY l=tac                         { Prover.AST.Try l }
  | REPEAT t=tac                      { Prover.AST.Repeat t }

  | ID                                { Prover.AST.Abstract ($1,[]) }
  | ID i=INT                          { Prover.AST.Abstract
                                          ($1,[Prover.Int i]) }
  | ID f=formula                      { Prover.AST.Abstract
                                          ($1,
                                           [Prover.Formula
                                              (Prover.parse_formula f)]) }

  | NOSIMPL t=tac                     { Prover.AST.Modifier
                                          ("nosimpl", t) }
  | CYCLE i=INT                       { Prover.AST.Abstract
                                         ("cycle",[Prover.Int i]) }
  | CYCLE MINUS i=INT                 { Prover.AST.Abstract
                                         ("cycle",[Prover.Int (-i)]) }

  | APPLY i=ID                        { Prover.AST.Abstract
                                          ("apply",
                                           [Prover.Goal_name i;
                                            Prover.Subst
                                              (Prover.parse_args i [])]) }
  | APPLY i=ID TO t=tactic_params     { Prover.AST.Abstract
                                          ("apply",
                                           [Prover.Goal_name i;
                                            Prover.Subst
                                              (Prover.parse_args i t) ]) }
  | EXISTS t=tactic_params            { Prover.AST.Abstract
                                          ("exists",
                                           [Prover.Subst
                                              (Prover.parse_args_exists t)]) }


qed:
| QED                                 { () }

undo:
| UNDO i=INT DOT                      { i }

tactic:
| t=tac DOT                           { t }

goal:
| GOAL i=ID COLON f=formula DOT   { Prover.Gm_goal (i, Prover.make_goal f) }
| GOAL f=formula DOT              { Prover.Gm_goal ("unnamed_goal",
                                                    Prover.make_goal f) }
| PROOF                           { Prover.Gm_proof }

theory:
| declaration theory             { () }
| SYSTEM process DOT             { Process.declare_system $2 }

top_process:
| process EOF                    { $1 }

interactive :
| theory                          { Prover.ParsedInputDescr }
| undo                            { Prover.ParsedUndo $1 }
| tactic                          { Prover.ParsedTactic $1 }
| qed                             { Prover.ParsedQed }
| goal                            { Prover.ParsedGoal $1 }
| EOF                             { Prover.EOF }
