import {NodeWeakMap, SyntaxNodeRef, SyntaxNode, IterMode} from "@lezer/common"
import {Completion, CompletionContext, CompletionResult, completeFromList, ifNotIn,
        snippetCompletion as snip} from "@codemirror/autocomplete"
import {syntaxTree} from "@codemirror/language"
import {Text} from "@codemirror/state"

const cache = new NodeWeakMap<readonly Completion[]>()

const tactics_completions: readonly Completion[] = [//{↓{

  {label:"use",detail:"H with v1 (, …, vn)? as intro_pat",
    info:"Instantiate a lemma or hypothesis on some arguments."},
  {label:"trans",detail:"i1: t1, ..., in : tn",
    info:"Prove an equivalence by transitivity."},
  {label:"sym",detail:"",info:"Prove an equivalence by symmetry."},
  {label:"have",detail:"H := H0 _ i2",info:"Add a new hypothesis."},
  {label:"case",detail:"Term",info:"Perform a case analysis."},
  {label:"const",detail:"Term",info:"Add the `const` tag to a variable."},
  {label:"adv",detail:"",info:""},
  {label:"collision",detail:"",
    info:`Collects all equalities between hashes\n
           occurring at toplevel in\n
           message hypotheses, and adds the equalities\n
           between messages that have the same hash with\n
           the same valid key.`},
  snip("depends ${Term1}, ${Term2}", 
  {label:"depends",detail:"Timestamp, Timestamp",
    info:`If the second action depends on the first\n
           action, and if the second action happened,\n
           add the corresponding timestamp inequality.`}),
  {label:"eqnames",detail:"",
    info:`Add index constraints resulting from names equalities,\n
                       modulo the known equalities.`},
  snip("euf ${H}", 
  {label:"euf",detail:"Hypothesis",
    info:"Apply the euf axiom to the given hypothesis name."}),
  {label:"executable",detail:"Term",info:
    `Assert that exec@_ implies exec@_ for all\n
                   previous timestamps.`},
  {label:"exists",detail:"v1, v2, ...",
    info:`In a Term: Introduce the existentially quantified\n
            variables in the conclusion of the judgment,\n
            using the arguments as existential witnesses.\n
            `},
  {label:"Exists",detail:"(i:index), …",info:"Quantifier in formula"},
  snip("splitseq ${Int}: (${Term})", 
  {label:"splitseq",detail:"Int: (Term)",
    info:"splits a sequence according to some boolean"}),
  snip("remember ${Term} as ${Var}", 
  {label:"remember",detail:"Term as Var",
    info:"substitute a term by a fresh variable"}),
  {label:"expand",detail:"Term(, Term)*",
    info:`Expand all occurences of the given macro inside the\n
                       goal.`},
  {label:"fresh",detail:"(Int|Name)",
    info:"Exploit the freshness of a name."},
  {label:"forall",detail:"",info:"Quantifer in Term"},
  {label:"Forall",detail:"",info:"Quantifer in formula"},
  {label:"help",detail:"Command*",info:`Display all available commands`},
  {label:"clear",detail:"",info:"Clear an hypothesis."},
  {label:"prof",detail:"",info:"Print profiling information."},
  {label:"induction",detail:"(Term|Int)",
    info:"Apply the induction scheme to the conclusion."},
  {label:"intro",detail:"a b _ c *",
    info:`Introduce topmost connectives of conclusion\n
          formula, when it can be done in an invertible,\n
          non-branching fashion.`},
  snip("apply ${F}", 
  {label:"apply",detail:"F",
  info:`Matches the goal with the conclusion of the formula F provided
   (F can be an hypothesis, a lemma, an axiom, or a proof term), trying
   to instantiate F variables by matching.
   Creates one subgoal for each premises of F.`}),
  {label:"generalize",detail:"Term( Term)*",
    info:"Generalize the goal on some terms"},
  {label:"dependent induction",detail:"(Term)*",
    info:"Apply the induction scheme to the conclusion."},
  {label:"revert",detail:"H1 H2",
    info:`Take an hypothesis H, and turns the conclusion C into \n
                      the implication H => C.`},
  {label:"destruct",detail:"H (as [A | [B C]])?",
    info:`Destruct an hypothesis. An optional And/Or\n
                      introduction pattern can be given.`},
  {label:"left",detail:"",
    info:`Reduce a goal with a disjunction conclusion\n
          into the goal where the conclusion has been\n
          replaced with the first disjunct.`},
  {label:"project",detail:"",
    info:`Turn a goal on a bi-system into
          one goal for each projection of the bi-system.`},
  {label:"right",detail:"",
    info:`Reduce a goal with a disjunction conclusion
          into the goal where the conclusion has been
          replaced with the second disjunct.`},
  {label:"simpl",detail:"",info:"Simplifies a goal, without closing it."},
  {label:"reduce",detail:"(~Var(:[v1(,v2)*])?)?",
    info:"Reduce the sequent."},
  {label:"split",detail:"",
    info:"G=> A & B is replaced by G=>A and goal G=>B."},
  {label:"subst",detail:"",
    info:`If i = t where i is a variable, substitute all occurences
          of i by t and remove i from the context variables.`},
  {label:"rewrite",detail:"Hyp Lemma Axiom (in H)?",
    info:`If t1 = t2, rewrite all occurences of t1 into t2 in the goal.`},
  {label:"true",detail:"",
    info:"Solves a goal when the conclusion is true."},
  snip("cca1 ${N}", 
  {label:"cca1",detail:"Int",
    info:"Apply the cca1 axiom on all instances of a ciphertext."}),
  snip("ddh ${generator}, ${name1}, ${name2}, ${name3}", 
  {label:"ddh",detail:"g, a, b, k",
    info:`It must be called on (generator, a, b, c) where
          (a,b,c) are strings that corresponds
          to names, but without any indices. It then
          applies ddh to all the copies of the names,
          and checks that all actions of the protocol
          uses the names in a correct way. Can be used
          in collaboration with some transitivity to
          obtain a system where ddh can be applied.`}),
  snip("gdh ${Hyp}, ${generator}", 
  {label:"gdh",detail:"H, g",info:`
    Applies the GDH assumption (including
    square-GDH) on H with generator g.
    `}),
  snip("cdh ${Hyp}, ${generator}", 
  {label:"cdh",detail:"Hyp, generator",
    info:`Applies the CDH assumption (including
         square-CDH) on H using generator g.`}),
  {label:"enckp",detail:"Int",
    info:`Key-privacy captures the property of an encryption to provide
          confidentiality of the encryption key.
          The term and new key can be passed as arguments,
          otherwise the tactic applies to the first subterm of the form
          enc(_,r,k) where r is a name and k features a diff operator.
    `},
  {label:"enrich",detail:"Term",
    info:`This is usually called before the induction, to enrich the
           induction hypothesis, and then allow to solve multiple cases
           more simply.`},
  {label:"expandall",detail:"",
    info:"Expand all possible macros in the sequent."},
  {label:"fa",detail:"(Int|Term)",info:`
    Local sequent:
     When we have G => f(u) = f(v), produces the
     goal G => u=v. Produces as many subgoals as
     arugment of the head function symbol.
     Global sequent:
     To prove that a goal containing f(u1,...,un) is
     diff-equivalent, one can prove that the goal containing the
     sequence u1,...,un is diff-equivalent.
    `},
  {label:"show",detail:"Term",info:`
    Print the messages given as argument. Can be used to
     print the values matching a pattern.
    `},
  {label:"deduce",detail:"Int",info:`
    When applied on an the ith element u of the biframe, \
   'deduce i' removes u if the biframe without u allows to bi-deduce \
   the whole biframe.
    `},
  {label:"prf",detail:"Int (Term)?",info:`
    It allows to replace a hash h(m,k) by a name,
     provided a proof obligation stating that the key k is only
     used as a hash key, and m is not hashed anywhere else.
     Behaves similarly to the fresh tactic.
    `},
  {label:"xor",detail:"Int(,Term(,Term)?)?",info:`
    Removes biterm (n(i0,...,ik) XOR t) if n(i0,...,ik) is fresh.
    `},
  {label:"intctxt",detail:"Hyp",info:`
    applies to a hypothesis of the form dec(c,k)<>fail,
    or dec(c,k) = t (in the latter case, generates as an additional goal
    that t <> fail)
    `},
  {label:"constseq",detail:"Int",info:"simplifies a constant sequence"},
  {label:"localize",detail:"H as H'",info:`
    Change a global hypothesis containing a reachability
    formula to a local hypothesis.
    `},
  {label:"memseq",detail:"Int Int",info:`
    prove that an biframe element appears in a
    sequence of the biframe.
    `},
  {label:"byequiv",detail:"",info:`
    transform an equivalence goal into a
    reachability goal.
    `},
  {label:"cycle",detail:"Int",info:`TODO`},
  {label:"congruence",detail:"",
    info:`Tries to derive false from the messages equalities.`},
  {label:"assumption",detail:"",
    info:`Concludes if the goal or false appears in the hypotheses.`},
  {label:"constraints",detail:"",
    info:`Tries to derive false from the trace formulas.`},
  {label:"refl",detail:"",
    info:`Closes a reflexive goal.`},
  {label:"admit",detail:"",
    info:`Admit goal.`},
  {label:"diffeq",detail:"",
    info:`Closes a reflexive goal up to equality`}
].map(t => {t.type = "function"; t.boost = 50;return t});//}↑}

const ScopeNodes = new Set([
 "Script", "Interactive", "Declaration", "Local_statement", "Global_statement", "Hint"
])

function defID(type: string) {
  return (node: SyntaxNodeRef, def: (node: SyntaxNodeRef, type: string) => void, outer: boolean) => {
    if (outer) return false
    let id = node.node.getChild("Lsymb")
    if (id) def(id, type)
    return true
  }
}

function getLsymb_decl(node: SyntaxNodeRef,def: (node: SyntaxNodeRef, type: string) => void) {
    let child = node.node.firstChild;
    if (child!.type.name == "Lsymb") 
      def(child!, "variable")
    else if (child = node.node.getChild("RIGHTINFIXSYMB"))
      def(child, "variable")
    else if (child = node.node.getChild("LEFTINFIXSYMB"))
      def(child, "variable")
}

const gatherCompletions: {
  [node: string]: (node: SyntaxNodeRef, def: (node: SyntaxNodeRef, type: string) => void, outer: boolean) => void | boolean
} = {
  Simpl_lval: defID("variable"),
  Lval(node, def) {
    for (let child = node.node.firstChild; child; child = child.nextSibling) {
      if (child.type.name == "Lsymb") def(child, "variable")
        else if (child.type.name == "RPAREN" ) break
    }
  },
  Lsymb_decl(node, def) {
  },
  Declaration(node, def) {
    console.log("declaration autocomplete called !")
    for (let child = node.node.firstChild; child; child = child.nextSibling) {
      if (child.type.name == "Lsymb") 
        def(child, "variable")
      if (child.type.name == "Lsymb_decl") 
        getLsymb_decl(child,def)
      if (child.type.name == "Ty") 
        def(child, "type")
      else if (child.type.name == "EQ" ) 
        break
    }
  },
  Local_statement(node, def) {
    console.log("local_statement autocomplete called !")
    let name_node = node.node.getChild("Statement_name")
    if (name_node) {
      let lsymb_node = name_node.node.getChild("Lsymb")
      if(lsymb_node)
        def(lsymb_node, "variable")
    }
  },
  // Sentence(node, def) {
  //   let child = node.node.firstChild
  //   gatherCompletions[child!.name]
  // },
  Global_statement(node, def) {
    console.log("global_statement autocomplete called !")
    let name_node = node.node.getChild("Statement_name")
    if (name_node) {
      let lsymb_node = name_node.node.getChild("Lsymb")
      if(lsymb_node)
        def(lsymb_node, "variable")
    }
  },
  Bty_info: defID("type")
}

function getScope(doc: Text, node: SyntaxNode) {
  console.log("getScope")
  let cached = cache.get(node)
  if (cached) return cached

  let completions: Completion[] = [], top = true
  function def(node: SyntaxNodeRef, type: string) {
    let name = doc.sliceString(node.from, node.to)
    completions.push({label: name, type})
  }
  node.cursor(IterMode.IncludeAnonymous).iterate(node => {
    if (node.name) {
      console.log("Autocompletion : "+node.name)
      let gather = gatherCompletions[node.name]
      console.log(gather)
      if (gather && gather(node, def, top) 
        || !top && ScopeNodes.has(node.name)) return false
      top = false
    } else if (node.to - node.from > 8192) {
      // Allow caching for bigger internal nodes
      for (let c of getScope(doc, node.node)) completions.push(c)
      return false
    }
  })
  cache.set(node, completions)
  return completions
}

// const Identifier = /^[\w\xa1-\uffff][\w\d\xa1-\uffff]*$/

const dontComplete = ["BlockComment"]


function inNodeType(type:string,node:SyntaxNode | null):boolean {
  do{
    if (node!.type.name == type)
      return true
    node = node!.parent
  }
  while(node)
  return false
}

function inBulletedTac(node:SyntaxNode | null):boolean {
  return (inNodeType("Bulleted_tactic",node) || inNodeType("Tactic",node))
}


/// Completion source that looks up locally defined declarations
export function localCompletionSource(context: CompletionContext): CompletionResult | null {
  let inner = syntaxTree(context.state).resolveInner(context.pos, -1)
  // if (dontComplete.indexOf(inner.name) > -1) return null
  let isLsymb = inner.type.name == "Lsymb" 
  let isType = inner.type.name == "Ty" 

    // || inner.to - inner.from < 20 && Identifier.test(context.state.sliceDoc(inner.from, inner.to))
  // if (!isWord && !context.explicit) return null
  let options: Completion[] = []
  for (let pos: SyntaxNode | null = inner; pos; pos = pos.parent) {
    if (ScopeNodes.has(pos.name)) {
      let scope_completions = getScope(context.state.doc, pos);
      options = options.concat(scope_completions);
    }
  }
  if (inBulletedTac(inner)){
    console.warn("In Proof !")
    options = options.concat(tactics_completions);
  }
  return {
    options,
    from: inner.from
  }
}


const globals: readonly Completion[] = [
  "false", "null", "true"
].map(n => ({label: n, type: "constant"})).concat([

  "index",
  "message",
  "boolean",
  "bool",
  "timestamp",
  "large",
  "name_fixed_length"
].map(n => ({label: n, type: "type"}))).concat([

  "input",
  "cond",
  "output",
  "exec",
  "frame",
  "seq",
  "diff",
  "happens",
  "len",
  "xor"
].map(n => ({label: n, type: "function"}))).concat([

  "aenc",
  "signature",
  "hash",
  "senc",
  "abstract",
  "op",
  "system",
  "type",
  "name",
  "action",
  "channel",
  "mutable",
  "process",
  "with oracle",
  "with hash",
  "where"
].map(n => ({label: n, type: "property"})))

export const snippets: readonly Completion[] = [
  snip("if ${Term} then (${Process}) else (${Process})", {
    label: "if",
    detail: " ${Term} then (${Process}) else (${Process})",
    info: "Process of form if _ then _ else _",
    type: "method"
  }),
  snip("try find ${bnds} such that (${Term}) in (${Term}) else (${Term})", {
    label: "find",
    detail: " ${bnds} such that (${Term}) in (${Term}) else (${Term})",
    info: "Process of form try find …",
    type: "method"
  }),
  snip("let ${Lsymb}:${Ty} = (${Term}) in (${Process})", {
    label: "let",
    detail: " ${Lsymb}:${Ty} = (${Term}) in (${Process})",
    info: "Process of form let _ = _ in",
    type: "method"
  }),
  snip("in(${Lsymb},${Lsymb})", {
    label: "in",
    detail: "(${CHANNEL},${Lsymb})",
    info: "Process in(c,x)` is used to receive some value from channel `c`, bound to the variable `x`",
    type: "method"
  }),
  snip("out(${Lsymb},${Term})", {
    label: "out",
    detail: "(${Lsymb},${Term})",
    info: "Process `out(c,m)` is used to send the Term `m` over the channel `c`",
    type: "method"
  }),
  snip("new ${Lsymb}:${Ty} ; ${Process}", {
    label: "new",
    detail: " ${Lsymb}:${Ty} ; ${Process}",
    info: "Process `new n` id used to instantiate a fresh name",
    type: "method"
  }),
  snip("fun ${ext_bnd_tagged} => ${Term}", {
    label: "fun",
    detail: " ${ext_bnd_tagged} => ${Term}",
    info: "Term fun",
    type: "keyword"
  }),
  snip("if ${Term} then (${Term}) else (${Term})", {
    label: "if",
    detail: " ${Term} then (${Term}) else (${Term})",
    info: "Term of form if _ then _ else _",
    type: "keyword"
  }),
  snip("include ${File}", {
    label: "include",
    detail: " File",
    info: "include 'File.sp'",
    type: "keyword"
  })]

/// Autocompletion for built-in Python globals and keywords.
export const globalCompletion = ifNotIn(dontComplete, completeFromList(globals.concat(snippets)))
