open Utils

module L = Location

type lsymb = string L.located

(*------------------------------------------------------------------*)
type namespace =
  | NChannel
  | NName
  | NAction
  | NFunction
  | NMacro
  | NSystem
  | NProcess

let pp_namespace fmt = function
  | NChannel  -> Fmt.pf fmt "Channel"
  | NName     -> Fmt.pf fmt "Name"
  | NAction   -> Fmt.pf fmt "Action"
  | NFunction -> Fmt.pf fmt "Function"
  | NMacro    -> Fmt.pf fmt "Macro"
  | NSystem   -> Fmt.pf fmt "System"
  | NProcess  -> Fmt.pf fmt "Process"

(*------------------------------------------------------------------*)
(** Type of symbols.
  * The group should be understood as a namespace,
  * though it does not correspond to the (poorly named) namespace type
  * below. *)
type symb = { group: string; name: string }

(** Symbols of type ['a t] are symbols of namespace ['a]. *)
type 'a t = symb

type group = string
let default_group = ""

type kind = Sorts.esort

type function_def =
  | Hash
  | AEnc
  | ADec
  | SEnc
  | SDec
  | Sign
  | CheckSign
  | PublicKey
  | Abstract of int

type macro_def =
  | Input | Output | Cond | Exec | Frame
  | State of int * kind
  | Global of int
  | Local of kind list * kind

type channel
type name
type action
type fname
type macro
type system
type process

type _ def =
  | Channel  : unit                 -> channel def
  | Name     : int                  -> name    def
  | Action   : int                  -> action  def
  | Function : (int * function_def) -> fname   def
  | Macro    : macro_def            -> macro   def
  | System   : unit                 -> system  def
  | Process  : unit                 -> process def

type edef =
  | Exists : 'a def -> edef
  | Reserved of namespace

type data = ..
type data += Empty
type data += AssociatedFunctions of (fname t) list


(*------------------------------------------------------------------*)
let to_string s = s.name

let pp fmt symb = Format.pp_print_string fmt symb.name

module Ms = Map.Make (struct type t = symb let compare = Stdlib.compare end)

(*------------------------------------------------------------------*)
module Table : sig
  type table_c = (edef * data) Ms.t

  type table = private { 
    cnt : table_c;
    tag : int;
  }

  val mk : table_c -> table
  val tag : table -> int
end = struct
  type table_c = (edef * data) Ms.t

  type table = { 
    cnt : table_c;
    tag : int;
  }
  
  let mk = 
    let cpt_tag = ref 0 in
    fun t ->
      { cnt = t; tag = (incr cpt_tag; !cpt_tag) }

  let tag t = t.tag
end

include Table

(*------------------------------------------------------------------*)
let empty_table : table = mk Ms.empty

let prefix_count_regexp = Pcre.regexp "([^0-9]*)([0-9]*)"

let table_add table name d = Ms.add name d table

let fresh ?(group=default_group) prefix table =
  let substrings = Pcre.exec ~rex:prefix_count_regexp prefix in
  let prefix = Pcre.get_substring substrings 1 in
  let i0 = Pcre.get_substring substrings 2 in
  let i0 = if i0 = "" then 0 else int_of_string i0 in
  let rec find i =
    let s = if i=0 then prefix else prefix ^ string_of_int i in
    let symb = {group;name=s} in
    if Ms.mem symb table then find (i+1) else symb
  in
  find i0

(*------------------------------------------------------------------*)
let edef_namespace : edef -> namespace = fun e ->
  match e with
  | Exists (Channel  _) -> NChannel
  | Exists (Name     _) -> NName
  | Exists (Action   _) -> NAction
  | Exists (Function _) -> NFunction
  | Exists (Macro    _) -> NMacro
  | Exists (System   _) -> NSystem
  | Exists (Process  _) -> NProcess
  | Reserved n          -> n

let get_namespace ?(group=default_group) (table : table) s =
  let s = { group; name=s } in
  let f (x,_) = edef_namespace x in
  omap f (Ms.find_opt s table.cnt)

(*------------------------------------------------------------------*)
(** {2 Error Handling} *)

type symb_err_i = 
  | Unbound_identifier    of string
  | Incorrect_namespace   of namespace * namespace (* expected, got *)
  | Multiple_declarations of string

type symb_err = L.t * symb_err_i

let pp_symb_error_i fmt = function
  | Unbound_identifier s -> Fmt.pf fmt "unknown symbol %s" s
  | Incorrect_namespace (n1, n2) ->
    Fmt.pf fmt "should be a %a but is a %a" 
      pp_namespace n1 pp_namespace n2

  | Multiple_declarations s ->
    Fmt.pf fmt "symbol %s already declared" s

let pp_symb_error pp_loc_err fmt (loc,e) =
  Fmt.pf fmt "%a%a."
    pp_loc_err loc
    pp_symb_error_i e

exception SymbError of symb_err

let symb_err l e = raise (SymbError (l,e))

(*------------------------------------------------------------------*)
(** {2 Namespaces} *)

let def_of_lsymb ?(group=default_group) (s : lsymb) (table : table) =
  let t = { group; name = L.unloc s } in
  try fst (Ms.find t table.cnt) with Not_found -> 
    symb_err (L.loc s) (Unbound_identifier (L.unloc s))

let is_defined ?(group=default_group) name (table : table) = 
  Ms.mem {group;name} table.cnt

type wrapped = Wrapped : 'a t * 'a def -> wrapped

let of_lsymb ?(group=default_group) (s : lsymb) (table : table) =
  let t = { group ; name = L.unloc s } in
  match Ms.find t table.cnt with
  | Exists d, _ -> Wrapped (t,d)
  | exception Not_found
  | Reserved _, _ -> 
      symb_err (L.loc s) (Unbound_identifier (L.unloc s))

let of_lsymb_opt ?(group=default_group) (s : lsymb) (table : table) =
  let t = { group; name = L.unloc s } in
  try match Ms.find t table.cnt with
    | Exists d, _ -> Some (Wrapped (t,d))
    | Reserved _, _ -> None
  with Not_found -> None

(*------------------------------------------------------------------*)
module type Namespace = sig
  type ns
  type def
  val reserve : table -> lsymb -> table * data t
  val reserve_exact : table -> lsymb -> table * ns t
  val define : table -> data t -> ?data:data -> def -> table
  val redefine : table -> data t -> ?data:data -> def -> table
  val declare :
    table -> lsymb -> ?data:data -> def -> table * ns t
  val declare_exact :
    table -> lsymb -> ?data:data -> def -> table * ns t
  val of_lsymb : lsymb -> table -> ns t
  val of_lsymb_opt : lsymb -> table -> ns t option
  val cast_of_string : string -> ns t

  val get_all       : ns t   -> table -> def * data
  val get_def       : ns t   -> table -> def
  val def_of_lsymb  : lsymb  -> table -> def
  val get_data      : ns t   -> table -> data
  val data_of_lsymb : lsymb  -> table -> data

  val iter : (ns t -> def -> data -> unit) -> table -> unit
  val fold : (ns t -> def -> data -> 'a -> 'a) -> 'a -> table -> 'a
end

module type S = sig
  type ns
  type local_def

  val namespace : namespace 
  val group : string
  val construct   : local_def -> ns def
  val deconstruct : loc:(L.t option) -> edef -> local_def
end

module Make (N:S) : Namespace
  with type ns = N.ns with type def = N.local_def = struct

  type ns = N.ns
  type def = N.local_def

  let group = N.group

  let reserve (table : table) (name : lsymb) =
    let symb = fresh ~group (L.unloc name) table.cnt in
    let table_c = Ms.add symb (Reserved N.namespace,Empty) table.cnt in
    mk table_c, symb

  let reserve_exact (table : table) (name : lsymb) =
    let symb = { group; name = L.unloc name } in
    if Ms.mem symb table.cnt then 
      symb_err (L.loc name) (Multiple_declarations (L.unloc name));

    let table_c = Ms.add symb (Reserved N.namespace,Empty) table.cnt in
    mk table_c, symb

  let define (table : table) symb ?(data=Empty) value =
    assert (fst (Ms.find symb table.cnt) = Reserved N.namespace) ;
    let table_c = Ms.add symb (Exists (N.construct value), data) table.cnt in
    mk table_c

  let redefine (table : table) symb ?(data=Empty) value =
    assert (Ms.mem symb table.cnt) ;
    let table_c = Ms.add symb (Exists (N.construct value), data) table.cnt in
    mk table_c

  let declare (table : table) (name : lsymb) ?(data=Empty) value =
    let symb = fresh ~group (L.unloc name) table.cnt in
    let table_c =
      table_add table.cnt symb (Exists (N.construct value), data)
    in
    mk table_c, symb

  let declare_exact (table : table) (name : lsymb) ?(data=Empty) value =
    let symb = { group; name = L.unloc name } in
    if Ms.mem symb table.cnt then 
      symb_err (L.loc name) (Multiple_declarations (L.unloc name));
    let table_c =
      table_add table.cnt symb (Exists (N.construct value), data)
    in
    mk table_c, symb

  let get_all (name:ns t) (table : table) =
    (* We know that [name] is bound in [table]. *)
    let def,data = Ms.find name table.cnt in
    N.deconstruct ~loc:None def, data

  let get_def name (table : table) = fst (get_all name table)
  let get_data name (table : table) = snd (get_all name table)

  let cast_of_string name = {group;name}

  let of_lsymb (name : lsymb) (table : table) =
    let symb = { group; name = L.unloc name } in
    try
      ignore (N.deconstruct
                ~loc:(Some (L.loc name)) 
                (fst (Ms.find symb table.cnt))) ;
      symb
    with Not_found -> 
      symb_err (L.loc name) (Unbound_identifier (L.unloc name))

  let of_lsymb_opt (name : lsymb) (table : table) =
    let symb = { group; name = L.unloc name } in
    try
      ignore (N.deconstruct
                ~loc:(Some (L.loc name))
                (fst (Ms.find symb table.cnt))) ;
      Some symb
    with Not_found -> None

  let def_of_lsymb (name : lsymb) (table : table) =
    try
      N.deconstruct ~loc:(Some (L.loc name))
        (fst (Ms.find { group; name = L.unloc name } table.cnt))
    with Not_found -> 
      symb_err (L.loc name) (Unbound_identifier (L.unloc name))

  let data_of_lsymb (name : lsymb) (table : table) =
    try
      let def,data = Ms.find { group; name = L.unloc name } table.cnt in
        (* Check that we are in the current namespace
         * before returning the associated data. *)
        ignore (N.deconstruct ~loc:(Some (L.loc name)) def) ;
        data
    with Not_found -> 
      symb_err (L.loc name) (Unbound_identifier (L.unloc name))

  let iter f (table : table) =
    Ms.iter
      (fun s (def,data) ->
         try f s (N.deconstruct ~loc:None def) data with
           | SymbError (_,Incorrect_namespace _) -> ())
      table.cnt

  let fold f acc (table : table) =
    Ms.fold
      (fun s (def,data) acc ->
         try
           let def = N.deconstruct ~loc:None def in
           f s def data acc
         with SymbError (_,Incorrect_namespace _) -> acc)
      table.cnt acc

end

let namespace_err (l : L.t option) c n =
  let l = match l with
    | None   -> L._dummy
    | Some l -> l
  in
  symb_err l (Incorrect_namespace (edef_namespace c, n))

module Action = Make (struct
  type ns = action
  type local_def = int

  let namespace = NAction

  let group = default_group
  let construct d = Action d
  let deconstruct ~loc = function
    | Exists (Action d) -> d
    | _ as c -> namespace_err loc c namespace
      
end)

module Name = Make (struct
  type ns = name
  type local_def = int

  let namespace = NName

  let group = default_group
  let construct d = Name d
  let deconstruct ~loc s = match s with
    | Exists (Name d) -> d
    | _ as c -> namespace_err loc c namespace
end)

module Channel = Make (struct
  type ns = channel
  type local_def = unit

  let namespace = NChannel

  let group = default_group
  let construct d = Channel d
  let deconstruct ~loc s = match s with
    | Exists (Channel d) -> d
    | _ as c -> namespace_err loc c namespace
end)

module System = Make (struct
  type ns = system
  type local_def = unit

  let namespace = NSystem
  
  let group = default_group
  let construct d = System d
  let deconstruct ~loc s = match s with
    | Exists (System d) -> d
    | _ as c -> namespace_err loc c namespace
end)

module Process = Make (struct
  type ns = process
  type local_def = unit

  let namespace = NProcess

  let group = "process"
  let construct d = Process d
  let deconstruct ~loc s = match s with
    | Exists (Process d) -> d
    | _ as c -> namespace_err loc c namespace
end)

module Function = Make (struct
  type ns = fname
  type local_def = int * function_def

  let namespace = NFunction

  let group = default_group
  let construct d = Function d
  let deconstruct ~loc s = match s with
    | Exists (Function d) -> d
    | _ as c -> namespace_err loc c namespace
end)

let is_ftype s ftype table =
  match Function.get_def s table with
    | _,t when t = ftype -> true
    | _ -> false
    | exception Not_found -> 
      (* TODO: location *)
      symb_err L._dummy (Unbound_identifier s.name)

module Macro = Make (struct
  type ns = macro
  type local_def = macro_def

  let namespace = NMacro

  let group = default_group
  let construct d = Macro d
  let deconstruct ~loc s = match s with
    | Exists (Macro d) -> d
    | _ as c -> namespace_err loc c namespace
end)

(*------------------------------------------------------------------*)
(** {2 Builtins} *)


(* reference used to build the table. Must not be exported in the .mli *)
let builtin_ref = ref empty_table

(** {Action builtins} *)

let mk_action a =
  let table, a = Action.reserve_exact !builtin_ref (L.mk_loc L._dummy a) in
  builtin_ref := table;
  a

let init_action = mk_action "init"

(** {3 Macro builtins} *)

let mk_macro m def =
  let table, m = Macro.declare_exact !builtin_ref (L.mk_loc L._dummy m) def in
  builtin_ref := table;
  m

let inp   = mk_macro "input"  Input
let out   = mk_macro "output" Output
let cond  = mk_macro "cond"   Cond
let exec  = mk_macro "exec"   Exec
let frame = mk_macro "frame"  Frame

(** {3 Channel builtins} *)

let dummy_channel_lsymb = L.mk_loc L._dummy "ø"
let table,dummy_channel =
  Channel.declare_exact !builtin_ref dummy_channel_lsymb ()
let () = builtin_ref := table

(** {3 Function symbols builtins} *)

let mk_fsymb f arity =
  let info = 0, Abstract arity in
  let table, f = Function.declare_exact !builtin_ref (L.mk_loc L._dummy f) info in
  builtin_ref := table;
  f

(** Diff *)

let fs_diff  = mk_fsymb "diff" 2

(** Boolean connectives *)

let fs_false  = mk_fsymb "false" 0
let fs_true   = mk_fsymb "true" 0
let fs_and    = mk_fsymb "and" 2
let fs_or     = mk_fsymb "or" 2
let fs_not    = mk_fsymb "not" 1
let fs_ite    = mk_fsymb "if" 3

(** Fail *)

let fs_fail   = mk_fsymb "fail" 0

(** Xor and its unit *)

let fs_xor    = mk_fsymb "xor" 2
let fs_zero   = mk_fsymb "zero" 0

(** Successor over natural numbers *)

let fs_succ   = mk_fsymb "succ" 1

(** Pairing *)

let fs_pair   = mk_fsymb "pair" 2
let fs_fst    = mk_fsymb "fst" 1
let fs_snd    = mk_fsymb "snd" 1

(** Exp **)

let fs_exp    = mk_fsymb "exp" 2
let fs_g      = mk_fsymb "g" 0

(** Empty *)

let fs_empty  = mk_fsymb "empty" 0

(** Length *)

let fs_len    = mk_fsymb "len" 1
let fs_zeroes = mk_fsymb "zeroes" 1


(** {3 Builtins table} *)

let builtins_table = !builtin_ref
