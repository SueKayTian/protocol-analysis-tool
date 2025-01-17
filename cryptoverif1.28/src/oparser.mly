%{
(*************************************************************
 *                                                           *
 *       Cryptographic protocol verifier                     *
 *                                                           *
 *       Bruno Blanchet and David Cadé                       *
 *                                                           *
 *       Copyright (C) ENS, CNRS, INRIA, 2005-2017           *
 *                                                           *
 *************************************************************)

(*

    Copyright ENS, CNRS, INRIA 
    contributors: Bruno Blanchet, Bruno.Blanchet@inria.fr
                  David Cadé

This software is a computer program whose purpose is to verify 
cryptographic protocols in the computational model.

This software is governed by the CeCILL-B license under French law and
abiding by the rules of distribution of free software.  You can  use, 
modify and/ or redistribute the software under the terms of the CeCILL-B
license as circulated by CEA, CNRS and INRIA at the following URL
"http://www.cecill.info". 

As a counterpart to the access to the source code and  rights to copy,
modify and redistribute granted by the license, users are provided only
with a limited warranty  and the software's author,  the holder of the
economic rights,  and the successive licensors  have only  limited
liability. 

In this respect, the user's attention is drawn to the risks associated
with loading,  using,  modifying and/or developing or reproducing the
software by the user in light of its specific status of free software,
that may mean  that it is complicated to manipulate,  and  that  also
therefore means  that it is reserved for developers  and  experienced
professionals having in-depth computer knowledge. Users are therefore
encouraged to load and test the software's suitability as regards their
requirements in conditions enabling the security of their systems and/or 
data to be ensured and,  more generally, to use and operate it in the 
same conditions as regards security. 

The fact that you are presently reading this means that you have had
knowledge of the CeCILL-B license and that you accept its terms.

*)
%}
%{

open Parsing_helper
open Types
open Ptree
exception Syntax

let cst_true = (PIdent ("true", dummy_ext), dummy_ext)

let dummy_channel = ("@dummy_channel", dummy_ext)

let return_channel = dummy_channel

%}

%token COMMA
%token LPAREN
%token RPAREN
%token LBRACKET
%token RBRACKET
%token BAR
%token SEMI
%token COLON
%token <Ptree.ident> IDENT
%token <Ptree.ident> STRING
%token <int> INT
%token <float> FLOAT
%token FOREACH
%token DO
%token LEQ
%token IF
%token THEN
%token ELSE
%token FIND
%token ORFIND
%token SUCHTHAT
%token DEFINED
%token EQUAL
%token DIFF
%token FORALL
%token EQUATION
%token PARAM
%token PROBA
%token TYPE
%token PROCESS
%token DOT
%token EOF
%token LET
%token QUERY
%token SECRET
%token SECRET1
%token PUBLICVARS
%token AND
%token OR
%token CONST
%token EQUIV
%token EQUIVLEFT
%token EQUIVRIGHT
%token MUL
%token DIV
%token ADD
%token SUB
%token POWER
%token SET
%token COLLISION
%token EVENT
%token IMPLIES
%token TIME
%token END
%token EVENT_ABORT
%token OTHERUSES
%token MAXLENGTH
%token LENGTH
%token MAX
%token COUNT
%token EPSFIND
%token EPSRAND
%token PCOLL1RAND
%token PCOLL2RAND
%token NEWORACLE
%token INJ
%token MAPSTO
%token DEF
%token LEFTARROW
%token RANDOM
%token RETURN
%token FUN
%token IN
%token DEFINE
%token EXPAND
%token LBRACE
%token RBRACE
%token PROOF
%token IMPLEMENTATION
%token READ
%token WRITE
%token GET
%token INSERT
%token TABLE
%token LETFUN

/* Precedence (from low to high) and associativities */
%left BAR
%right OR
%right AND
%left ADD SUB
%left MUL DIV
%nonassoc EQUAL
%nonassoc DIFF
%nonassoc FOREACH

%start all
%type <Ptree.decl list * Ptree.process_e> all

%start lib
%type <Ptree.decl list> lib

%start instruct
%type <Ptree.process_e> instruct

%start cryptotransfinfo
%type <Ptree.crypto_transf_user_info> cryptotransfinfo

%start term
%type <Ptree.term_e> term

%start allowed_coll
%type <((Ptree.ident * int) list * Ptree.ident option) list> allowed_coll

%%

lib:
	FUN IDENT LPAREN identlist RPAREN COLON IDENT options DOT lib
	{ (FunDecl($2, $4, $7, $8)) :: $10 }
|       EVENT IDENT DOT lib
        { (EventDecl($2, [])) :: $4 }
|       EVENT IDENT LPAREN identlist RPAREN DOT lib
        { (EventDecl($2, $4)) :: $7 }
|	FORALL vartypelist SEMI term DOT lib
	{ (Statement($2, $4)) :: $6 }
|       EQUATION IDENT LPAREN identlist RPAREN DOT lib
        { (BuiltinEquation($2, $4)) :: $7 }
|	LET IDENT EQUAL process DOT lib
	{ (PDef($2,$4)) :: $6 }
|       SET IDENT EQUAL IDENT DOT lib
        { (Setting($2,S $4)) :: $6 }
|       SET IDENT EQUAL INT DOT lib
        { (Setting($2,I $4)) :: $6 }
|       QUERY queryseq DOT lib
        { (Query($2)) :: $4 }
|       PARAM neidentlist options DOT lib
        { (List.map (fun x -> (ParamDecl(x, $3))) $2) @ $5 }
|       PROBA IDENT DOT lib
        { (ProbabilityDecl($2)) :: $4 }
|       CONST neidentlist COLON IDENT DOT lib
        { (List.map (fun x -> (ConstDecl(x,$4))) $2) @ $6 }
|       TYPE IDENT options DOT lib
        { (TypeDecl($2,$3)) :: $5 }
|       EQUIV eqname eqmember EQUIVLEFT probaf EQUIVRIGHT optpriority eqmember DOT lib
        { (EqStatement($2, $3, $8, $5, $7)) :: $10 }
|       COLLISION newlist FORALL vartypelist SEMI RETURN LPAREN term RPAREN EQUIVLEFT probaf EQUIVRIGHT RETURN LPAREN term RPAREN DOT lib
        { (Collision($2, $4, $8, $11, $15)) :: $18 }
|       COLLISION newlist RETURN LPAREN term RPAREN EQUIVLEFT probaf EQUIVRIGHT RETURN LPAREN term RPAREN DOT lib
        { (Collision($2, [], $5, $8, $12)) :: $15 }
|       DEFINE IDENT LPAREN identlist RPAREN LBRACE lib RBRACE lib
        { (Define($2, $4, $7)) :: $9 }
|       EXPAND IDENT LPAREN identlist RPAREN DOT lib
        { (Expand($2, $4)) :: $7 }
|       PROOF LBRACE proof RBRACE lib
        { (Proofinfo($3))::$5 }
|       IMPLEMENTATION impllist DOT lib
        { (Implementation($2)) :: $4 }
|       TABLE IDENT LPAREN neidentlist RPAREN DOT lib
        { (TableDecl($2,$4)) :: $7 }
|       LETFUN IDENT EQUAL term DOT lib
        { (LetFun($2,[],$4)) :: $6 }
|       LETFUN IDENT LPAREN vartypelist RPAREN EQUAL term DOT lib
        { (LetFun($2,$4,$7)) :: $9 }
| 
        { [] }

impllist:
        impl
        { [$1] }
|       impl SEMI impllist
        { $1 :: $3 }
          
impl:
        TYPE IDENT EQUAL typeid typeoptions
        { Type($2,$4,$5) }
|       FUN IDENT EQUAL STRING functionoptions
        { Function($2,$4,$5) }
|       TABLE IDENT EQUAL STRING
        { ImplTable($2,$4) }
|       CONST IDENT EQUAL STRING
        { Constant($2,$4) }

typeid:
        INT
        { TypeSize ($1) }
|       STRING
        { TypeName ($1) }

stringlistne:
        STRING
        { [$1] }
|       STRING COMMA stringlistne
        { $1::$3 }

typeopt:
        IDENT EQUAL stringlistne
        { $1,$3 }

typeoptlist:
|       typeopt
        { [$1] }
|       typeopt SEMI typeoptlist
        { $1::$3 }

typeoptions:
|       LBRACKET typeoptlist RBRACKET
        { $2 }
| 
        { [] }

funopt:
        IDENT EQUAL STRING
        { $1,$3 }

funoptlist:
|       funopt
        { [$1] }
|       funopt SEMI funoptlist
        { $1::$3 }

functionoptions:
        LBRACKET funoptlist RBRACKET
        { $2 }
|       
        { [] }

programoptions:
        LBRACKET progoptlist RBRACKET
        { $2 }
|       
        { [] }

progoptlist:
        progopt
        { [$1] }
|       progopt COMMA progoptlist
        { $1 :: $3 }

progopt:
        IDENT WRITE IDENT
        { PWrite($1,$3) }
|       IDENT READ IDENT
        { PRead($1,$3) }

prooftoken:
        IDENT
        { $1 }
|       STRING
        { $1 }
|       INT
        { string_of_int $1, parse_extent() }
|       MUL
        { "*", parse_extent() }
|       DOT
        { ".", parse_extent() }
|       SET
        { "set", parse_extent() }
|       INSERT
        { "insert", parse_extent() }
|       EQUAL
        { "=", parse_extent() }
|       COMMA
        { ",", parse_extent() }
|       LPAREN
        { "(", parse_extent() }
|       RPAREN
        { ")", parse_extent() }

proofcommand:
        prooftoken
        { [$1] }
|       prooftoken proofcommand
        { $1 :: $2 }

proof:
        proofcommand
	{ [$1] }
|       proofcommand SEMI proof
        { $1 :: $3 }

options:
        LBRACKET neidentlist RBRACKET
        { $2 }
| 
        { [] }

all:
        lib PROCESS process EOF
	{ $1, $3 }

identlist:
        
        { [] }
|       neidentlist
        { $1 }

neidentlist:
        IDENT 
        { [$1] }
|       IDENT COMMA neidentlist
        { $1 :: $3 }

vartypelist:

        { [] }
|       nevartypelist
        { $1 }

nevartypelist:
        IDENT COLON IDENT
        { [($1, $3)] }
|       IDENT COLON IDENT COMMA nevartypelist
        { ($1, $3) :: $5 }

term:
	IDENT LPAREN termseq RPAREN
	{ PFunApp ($1, $3), parse_extent() }
|       INJ COLON IDENT 
        { PInjEvent($3, []), parse_extent() }
|       INJ COLON IDENT LPAREN termseq RPAREN
        { PInjEvent($3, $5), parse_extent() }
|	IDENT
	{ PIdent ($1), parse_extent() }
|       IDENT LBRACKET termseq RBRACKET
        { PArray ($1, $3), parse_extent() }
|	LPAREN termseq RPAREN
	{ match $2 with
	    [t] -> t (* Allow parentheses for priorities of infix operators;
			Tuples cannot have one element. *)
	  | l -> PTuple(l), parse_extent() }
|       IF findcond THEN term ELSE term
        { begin
	  match $2 with
	    ([], t) -> PTestE(t, $4, $6)
	  | (def_list, t) -> 
	      PFindE([(ref [], [], def_list, t, $4)], $6, [])
	  end, parse_extent() }
|       FIND options findlistterm ELSE term
        { PFindE($3, $5, $2), parse_extent() }
|       basicpattern LEFTARROW term SEMI term
        { PLetE($1,$3,$5,None), parse_extent() }
|       LET pattern EQUAL term IN term ELSE term
        { PLetE($2,$4,$6,Some $8), parse_extent() }
|       LET pattern EQUAL term IN term
        { PLetE($2,$4,$6,None), parse_extent() }
| 	IDENT RANDOM IDENT SEMI term
	{ PResE($1, $3, $5), parse_extent() }
|       EVENT_ABORT IDENT
        { PEventAbortE($2), parse_extent() }
|       EVENT IDENT SEMI term
        { PEventE((PFunApp($2, []), parse_extent()), $4), parse_extent() }
|       EVENT IDENT LPAREN termseq RPAREN SEMI term
        { PEventE((PFunApp($2, $4), parse_extent()), $7), parse_extent() }
|       INSERT IDENT LPAREN termseq RPAREN SEMI term
        { PInsertE($2,$4,$7), parse_extent() }
|       GET IDENT LPAREN patternseq RPAREN SUCHTHAT term IN term ELSE term
        { PGetE($2,$4,Some $7,$9,$11), parse_extent() }
|       GET IDENT LPAREN patternseq RPAREN IN term ELSE term
        { PGetE($2,$4,None,$7,$9), parse_extent() }
|       term EQUAL term
        { PEqual($1, $3), parse_extent() }
|       term DIFF term
        { PDiff($1, $3), parse_extent() }
|       term OR term
        { POr($1, $3), parse_extent() }
|       term AND term
        { PAnd($1, $3), parse_extent() }

vref:
    IDENT LBRACKET termseq RBRACKET
    { $1,$3 }
|   IDENT
    { $1, [] }
    
vreflist:
    vref
    { [$1] }
|   vref COMMA vreflist
    { $1::$3 }

otherusescond:
    OTHERUSES LPAREN vreflist MAPSTO vref RPAREN
    { None }
|   OTHERUSES LPAREN vref RPAREN
    { None }

findcond1:
    DEFINED LPAREN vreflist RPAREN AND otherusescond AND term
    { ($3, $8) }
|   DEFINED LPAREN vreflist RPAREN AND otherusescond
    { ($3, cst_true) }
|   DEFINED LPAREN vreflist RPAREN AND term
    { ($3, $6) }
|   DEFINED LPAREN vreflist RPAREN 
    { ($3, cst_true) }

findcond:
    findcond1
    { $1 }
|   term
    { ([], $1) }
|   LPAREN findcond1 RPAREN
    { $2 }

findoneterm:
    tidentseq SUCHTHAT findcond THEN term
    { let (def_list, t) = $3 in
      (ref [], $1, def_list, t, $5) }

findlistterm:
    findoneterm
    { [$1] }
|   findoneterm ORFIND findlistterm
    { $1 :: $3 }

netidentseq:
    IDENT LEQ IDENT
    { [$1,$3] }
|   IDENT LEQ IDENT COMMA netidentseq
    { ($1,$3)::$5 }

tidentseq:
    netidentseq
    { $1 }
| 
    { [] }

netermseq:
	term COMMA netermseq
	{ $1 :: $3 }
|	term 
	{ [$1] }

termseq:
        netermseq
        { $1 }
| 
        { [] }

progbegin:
        IDENT programoptions LBRACE
        {($1,$2)}

progend:
        RBRACE
        {true}
|
        {false}

process:
        progbegin process
        { PBeginModule($1, $2), parse_extent() }
|	LPAREN process RPAREN
	{ $2 }
|	IDENT
	{ PLetDef $1, parse_extent() }
|	FOREACH IDENT LEQ IDENT DO process %prec FOREACH
	{ PRepl (ref None,Some $2,$4,$6), parse_extent() }
|	INT 
	{ let x = $1 in
	  if x = 0 then PNil, parse_extent() else 
          input_error ("The only integer in a process is 0 for the nil process") (parse_extent()) }
| 	IDENT RANDOM IDENT optprocess
	{ PRestr($1, $3, $4), parse_extent() }
|	IF findcond THEN process optelse
        { match $2 with
	    ([], t) -> PTest(t, $4, $5), parse_extent()
	  | (def_list, t) -> 
	      PFind([(ref [], [], def_list, t, $4)], $5, []), parse_extent() }
|       FIND options findlistproc optelse
        { PFind($3,$4,$2), parse_extent() }
|       INSERT IDENT LPAREN termseq RPAREN optprocess
        { PInsert($2,$4,$6), parse_extent() }
|       GET IDENT LPAREN patternseq RPAREN SUCHTHAT term IN process optelse
        { PGet($2,$4,Some $7,$9,$10), parse_extent() }
|       GET IDENT LPAREN patternseq RPAREN IN process optelse
        { PGet($2,$4,None,$7,$8), parse_extent() }
|       EVENT IDENT optprocess
        { PEvent((PFunApp($2, []), parse_extent()), $3), parse_extent() }
|       EVENT IDENT LPAREN termseq RPAREN optprocess
        { PEvent((PFunApp($2, $4), parse_extent()), $6), parse_extent() }
| 	basicpattern LEFTARROW term
	{ PLet($1,$3,(PYield, parse_extent()),(PYield, parse_extent())), parse_extent() }
| 	basicpattern LEFTARROW term SEMI process 
	{ PLet($1,$3,$5,(PYield, parse_extent())), parse_extent() }
| 	LET pattern EQUAL term
	{ PLet($2,$4,(PYield, parse_extent()),(PYield, parse_extent())), parse_extent() }
| 	LET pattern EQUAL term IN process optelse
	{ PLet($2,$4,$6,$7), parse_extent() }
|	IDENT LPAREN patternseq RPAREN DEF process
	{ let (_,ext) = $1 in
	  PInput($1,(PPatTuple $3, ext),$6), parse_extent() }
|	RETURN LPAREN termseq RPAREN progend optinputprocess
	{ POutput($5,return_channel, (PTuple($3), parse_extent()),$6), parse_extent() }
|	RETURN progend optinputprocess
	{ POutput($2,return_channel, (PTuple [], parse_extent()),$3), parse_extent() }
|       END
        { PYield, parse_extent() }
|       EVENT_ABORT IDENT
        { PEventAbort($2), parse_extent() }
|	process BAR process
	{ PPar($1,$3), parse_extent() }

findoneproc:
    tidentseq SUCHTHAT findcond THEN process
    { let (def_list, t) = $3 in
      (ref [], $1, def_list, t, $5) }

findlistproc:
    findoneproc
    { [$1] }
|   findoneproc ORFIND findlistproc
    { $1 :: $3 }

optprocess:
        SEMI process
        { $2 }
|       
        { PYield, parse_extent() }        

optinputprocess:
        SEMI process
        { $2 }
|       
        { PNil, parse_extent() }        

optelse:
        ELSE process
        { $2 }
|
        { PYield, parse_extent() }

basicpattern:
  IDENT
    { PPatVar($1,None), parse_extent() }
| IDENT COLON IDENT
    { PPatVar($1,Some $3), parse_extent() }

pattern:
  IDENT
    { PPatVar($1,None), parse_extent() }
| IDENT COLON IDENT
    { PPatVar($1,Some $3), parse_extent() }
| IDENT LPAREN patternseq RPAREN
    { PPatFunApp($1,$3), parse_extent() }
| LPAREN patternseq RPAREN
    {  match $2 with
	    [t] -> t (* Allow parentheses for priorities of infix operators;
			Tuples cannot have one element. *)
	  | l -> PPatTuple($2), parse_extent() }
| EQUAL term
    { PPatEqual($2), parse_extent() }

nepatternseq:
  pattern COMMA nepatternseq
    { $1 :: $3 }
| pattern
    { [$1] }

patternseq:
  nepatternseq
    { $1 }
| 
    { [] }

queryseq:
    query
    { [$1] }
|   query COMMA queryseq
    { $1::$3 }

query:
    SECRET IDENT optpublicvars
    { PQSecret ($2,$3) }
|   SECRET1 IDENT optpublicvars
    { PQSecret1 ($2,$3) }
|   vartypeilist SEMI EVENT term IMPLIES term 
    { PQEvent($1, $4, $6) }
|   EVENT term IMPLIES term 
    { PQEvent([], $2, $4) }

optpublicvars:
    
    { None }
|   PUBLICVARS identlist
    { Some $2 }

procasterm:
        RETURN LPAREN term RPAREN
        { $3 }
|       LPAREN procasterm RPAREN
        { $2 }
|       IF findcond THEN procasterm ELSE procasterm
        { begin
	  match $2 with
	    ([], t) -> PTestE(t, $4, $6)
	  | (def_list, t) -> 
	      PFindE([(ref [], [], def_list, t, $4)], $6, [])
	  end, parse_extent() }
|       FIND options findlistprocasterm ELSE procasterm
        { PFindE($3, $5, $2), parse_extent() }
|       basicpattern LEFTARROW term SEMI procasterm
        { PLetE($1,$3,$5,None), parse_extent() }
|       LET pattern EQUAL term IN procasterm ELSE procasterm
        { PLetE($2,$4,$6,Some $8), parse_extent() }
|       LET pattern EQUAL term IN procasterm
        { PLetE($2,$4,$6,None), parse_extent() }
| 	IDENT RANDOM IDENT SEMI procasterm
	{ PResE($1, $3, $5), parse_extent() }
|       EVENT_ABORT IDENT
        { PEventAbortE($2), parse_extent() }

findoneprocasterm:
    tidentseq SUCHTHAT findcond THEN procasterm
    { let (def_list, t) = $3 in
      (ref [], $1, def_list, t, $5) }

findlistprocasterm:
    findoneprocasterm
    { [$1] }
|   findoneprocasterm ORFIND findlistprocasterm
    { $1 :: $3 }

eqname:
    IDENT
    { CstName $1 }
|   IDENT LPAREN IDENT RPAREN
    { ParName($1,$3) }
|  
    { NoName }

eqmember:
    funmode
    { [$1], parse_extent() }
|   funmode BAR eqmember
    { $1 :: (fst $3), parse_extent() }


funmode:
    fungroup
    { $1,None, parse_extent() }
|   fungroup LBRACKET IDENT RBRACKET
    { $1,Some $3, parse_extent() }

newlist:
    
    { [] }
|   IDENT RANDOM IDENT SEMI newlist
    { ($1,$3)::$5 }

funlist:
    fungroup
    { [$1] }
|   fungroup BAR funlist
    { $1 :: $3 }

newlistfunlist:
    fungroup
    { [],[$1] }
|   LPAREN funlist RPAREN
    { [],$2 }
|   IDENT RANDOM IDENT options SEMI newlistfunlist
    { let (n,r) = $6 in (($1,$3,$4)::n),r }

optpriority:
    options LBRACKET INT RBRACKET 
    { $3, $1 }
|   LBRACKET INT RBRACKET options
    { $2, $4 }
|   options
    { 0, $1 }

vartypeilist:

        { [] }
|       nevartypeilist
        { $1 }

nevartypeilist:
        IDENT COLON IDENT
        { [($1, Tid $3)] }
|       IDENT COLON IDENT COMMA nevartypeilist
        { ($1, Tid $3) :: $5 }
|       IDENT LEQ IDENT
        { [($1, TBound $3)] }
|       IDENT LEQ IDENT COMMA nevartypeilist
        { ($1, TBound $3) :: $5 }

fungroup:
    IDENT LPAREN vartypeilist RPAREN optpriority DEF procasterm 
    { PFun($1, $3, $7, $5) }
|   FOREACH IDENT LEQ IDENT DO newlistfunlist 
    { let (n,r) = $6 in
      PReplRestr((ref None, Some $2, $4), n, r) }


probaf:
        LPAREN probaf RPAREN
        { $2 }
|       probaf ADD probaf
        { PAdd($1,$3), parse_extent() }
|       probaf SUB probaf
        { PSub($1, $3), parse_extent() }
|       probaf MUL probaf
        { PProd($1,$3), parse_extent() }
|       probaf DIV probaf
        { PDiv($1,$3), parse_extent() }
|       MAX LPAREN probaflist RPAREN
        { PMax($3), parse_extent() }
|       IDENT
        { (PPIdent $1), parse_extent() }
|       COUNT IDENT
        { (PCount $2), parse_extent() }
|       IDENT LPAREN probaflist RPAREN
        { (PPFun($1,$3)), parse_extent() }
|       BAR IDENT BAR
        { PCard($2), parse_extent() }
|       TIME
        { PTime, parse_extent() }
|       TIME LPAREN IDENT probaflistopt RPAREN
        { PActTime(PAFunApp $3, $4), parse_extent() }
|       TIME LPAREN LET IDENT probaflistopt RPAREN
        { PActTime(PAPatFunApp $4, $5), parse_extent() }
|       TIME LPAREN FOREACH RPAREN
        { PActTime(PAReplIndex, []), parse_extent() }
|       TIME LPAREN LBRACKET INT RBRACKET RPAREN
        { PActTime(PAArrayAccess $4, []), parse_extent() }
|       TIME LPAREN EQUAL IDENT probaflistopt RPAREN
        { PActTime(PACompare $4, $5), parse_extent() }
|       TIME LPAREN LPAREN identlist RPAREN probaflistopt RPAREN
        { PActTime(PAAppTuple $4, $6), parse_extent() }
|       TIME LPAREN LET LPAREN identlist RPAREN probaflistopt RPAREN
        { PActTime(PAPatTuple $5, $7), parse_extent() }
|       TIME LPAREN AND RPAREN
        { PActTime(PAAnd, []), parse_extent() }
|       TIME LPAREN OR RPAREN
        { PActTime(PAOr, []), parse_extent() }
|       TIME LPAREN RANDOM IDENT RPAREN
        { PActTime(PANew $4, []), parse_extent() }
|       TIME LPAREN NEWORACLE RPAREN
        { PActTime(PANewChannel, []), parse_extent() }
|       TIME LPAREN IF RPAREN
        { PActTime(PAIf, []), parse_extent() }
|       TIME LPAREN FIND INT RPAREN
        { PActTime(PAFind $4, []), parse_extent() }
|       INT
        { let x = $1 in
	  if x = 0 then (PPZero,parse_extent())  else 
          (PCst x,parse_extent())  }
|       FLOAT
        { let x = $1 in
	  if x = 0.0 then (PPZero,parse_extent())  else 
	  (PFloatCst x,parse_extent())  }
|       MAXLENGTH LPAREN term RPAREN
        { PMaxlength($3), parse_extent() }
|       LENGTH LPAREN IDENT probaflistopt RPAREN
        { PLength($3, $4), parse_extent() }
|       LENGTH LPAREN LPAREN identlist RPAREN probaflistopt RPAREN
        { PLengthTuple($4, $6), parse_extent() }
|       EPSFIND
        { PEpsFind, parse_extent() }
|       EPSRAND LPAREN IDENT RPAREN
        { PEpsRand($3), parse_extent() }
|       PCOLL1RAND LPAREN IDENT RPAREN
        { PPColl1Rand($3), parse_extent() }
|       PCOLL2RAND LPAREN IDENT RPAREN
        { PPColl2Rand($3), parse_extent() }

probaflistopt:
       COMMA probaflist 
       { $2 }
| 
       { [] }

probaflist:
       probaf
       { [$1] }
|      probaf COMMA probaflist
       { $1 :: $3 }

/* Instructions, for manual insertion of an instruction in a game */

instruct:
    IDENT RANDOM IDENT 
    { PRestr($1, $3, (PYield, parse_extent())), parse_extent() }
|   IF findcond THEN
    { 
      let yield = (PYield, parse_extent()) in
      match $2 with
	([], t) -> PTest(t, yield, yield), parse_extent()
      | (def_list, t) -> 
	  PFind([(ref [], [], def_list, t, yield)], yield, []), parse_extent()
    }
|   FIND findlistins
    { PFind($2, (PYield, parse_extent()), []), parse_extent() }
|   EVENT IDENT
    { PEvent((PFunApp($2, []), parse_extent()), (PYield, parse_extent())), parse_extent() }
|   EVENT IDENT LPAREN termseq RPAREN 
    { PEvent((PFunApp($2, $4), parse_extent()), (PYield, parse_extent())), parse_extent() }
|   basicpattern LEFTARROW term 
    { PLet($1,$3,(PYield, parse_extent()),(PYield, parse_extent())), parse_extent() }
|   LET pattern EQUAL term IN
    { PLet($2,$4,(PYield, parse_extent()),(PYield, parse_extent())), parse_extent() }

findoneins:
    tidentseq SUCHTHAT findcond THEN 
    { let (def_list, t) = $3 in
      (ref [], $1, def_list, t, (PYield, parse_extent())) }

findlistins:
    findoneins
    { [$1] }
|   findoneins ORFIND findlistins
    { $1 :: $3 }

/* Limits on elimination of collisions */

factor:
    IDENT
    { ($1, 1) }
|   IDENT POWER INT
    { ($1, $3) }

num:
    factor MUL num
    { $1 :: $3 }
|   factor
    { [$1] }

quot:
    num DIV IDENT
    { ($1, Some $3) }
|   COLLISION MUL num
    { ($3, None) }

allowed_coll:
    quot
    { [$1] }
|   quot COMMA allowed_coll
    { $1 :: $3 }

/* User information for the cryptographic transformation */

identmapping:
    IDENT MAPSTO IDENT
    { [$1,$3] }
|   IDENT MAPSTO IDENT COMMA identmapping
    { ($1,$3)::$5 }

intidentmapping:
    INT MAPSTO IDENT
    { [$1,$3] }
|   INT MAPSTO IDENT COMMA intidentmapping
    { ($1,$3)::$5 }

detailedinfo:
    IDENT COLON identmapping
    { PVarMapping($1, $3, false) }
|   IDENT COLON identmapping DOT
    { PVarMapping($1, $3, true) }
|   IDENT COLON intidentmapping
    { PTermMapping($1, $3, false) }
|   IDENT COLON intidentmapping DOT
    { PTermMapping($1, $3, true) }

detailedinfolist:
    detailedinfo
    { [$1] }
|   detailedinfo SEMI detailedinfolist
    { $1::$3 }

neidentlistnosep:
        IDENT 
        { [$1] }
|       IDENT neidentlistnosep
        { $1 :: $2 }

cryptotransfinfo:
    
    { PVarList([],false) }
|   MUL
    { PRepeat }
|   neidentlistnosep
    { PVarList($1, false) }
|   neidentlistnosep DOT
    { PVarList($1, true) }
|   detailedinfolist
    { PDetailed($1) }
