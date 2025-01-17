type token =
  | COMMA
  | LPAREN
  | RPAREN
  | LBRACKET
  | RBRACKET
  | BAR
  | SEMI
  | COLON
  | IDENT of (Ptree.ident)
  | STRING of (Ptree.ident)
  | INT of (int)
  | FLOAT of (float)
  | FOREACH
  | DO
  | LEQ
  | IF
  | THEN
  | ELSE
  | FIND
  | ORFIND
  | SUCHTHAT
  | DEFINED
  | EQUAL
  | DIFF
  | FORALL
  | EQUATION
  | PARAM
  | PROBA
  | TYPE
  | PROCESS
  | DOT
  | EOF
  | LET
  | QUERY
  | SECRET
  | SECRET1
  | PUBLICVARS
  | AND
  | OR
  | CONST
  | EQUIV
  | EQUIVLEFT
  | EQUIVRIGHT
  | MUL
  | DIV
  | ADD
  | SUB
  | POWER
  | SET
  | COLLISION
  | EVENT
  | IMPLIES
  | TIME
  | END
  | EVENT_ABORT
  | OTHERUSES
  | MAXLENGTH
  | LENGTH
  | MAX
  | COUNT
  | EPSFIND
  | EPSRAND
  | PCOLL1RAND
  | PCOLL2RAND
  | NEWORACLE
  | INJ
  | MAPSTO
  | DEF
  | LEFTARROW
  | RANDOM
  | RETURN
  | FUN
  | IN
  | DEFINE
  | EXPAND
  | LBRACE
  | RBRACE
  | PROOF
  | IMPLEMENTATION
  | READ
  | WRITE
  | GET
  | INSERT
  | TABLE
  | LETFUN

val all :
  (Lexing.lexbuf  -> token) -> Lexing.lexbuf -> Ptree.decl list * Ptree.process_e
val lib :
  (Lexing.lexbuf  -> token) -> Lexing.lexbuf -> Ptree.decl list
val instruct :
  (Lexing.lexbuf  -> token) -> Lexing.lexbuf -> Ptree.process_e
val cryptotransfinfo :
  (Lexing.lexbuf  -> token) -> Lexing.lexbuf -> Ptree.crypto_transf_user_info
val term :
  (Lexing.lexbuf  -> token) -> Lexing.lexbuf -> Ptree.term_e
val allowed_coll :
  (Lexing.lexbuf  -> token) -> Lexing.lexbuf -> ((Ptree.ident * int) list * Ptree.ident option) list
