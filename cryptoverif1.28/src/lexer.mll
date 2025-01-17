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
{
open Parsing_helper
open Parser
open Types
  
let create_hashtable size init =
  let tbl = Hashtbl.create size in
  List.iter (fun (key,data) -> Hashtbl.add tbl key data) init;
  tbl

let keyword_table =
  create_hashtable 11
[ "new", NEW;
  "out", OUT;
  "in", IN;
  "if", IF;
  "then", THEN;
  "else", ELSE;
  "find", FIND;
  "orfind", ORFIND;
  "suchthat", SUCHTHAT;
  "fun", FUN;
  "param", PARAM;
  "forall", FORALL;
  "equation", EQUATION;
  "proba", PROBA;
  "type", TYPE;
  "equiv", EQUIV;
  "process", PROCESS;
  "let", LET;
  "query", QUERY;
  "secret", SECRET;
  "secret1", SECRET1;
  "public_vars", PUBLICVARS;
  "const", CONST;
  "channel", CHANNEL;
  "set", SET;
  "defined", DEFINED;
  "collision", COLLISION;
  "event", EVENT;
  "time", TIME;
  "yield", YIELD;
  "event_abort", EVENT_ABORT;
  "otheruses", OTHERUSES;
  "maxlength", MAXLENGTH;
  "length", LENGTH;
  "max", MAX;
  "eps_find", EPSFIND;
  "eps_rand", EPSRAND;
  "Pcoll1rand", PCOLL1RAND;
  "Pcoll2rand", PCOLL2RAND;
  "newChannel", NEWCHANNEL;
  "inj", INJ;
  "define", DEFINE;
  "expand", EXPAND;
  "proof", PROOF;
  "implementation", IMPLEMENTATION;
  "get", GET;
  "insert", INSERT;
  "table", TABLE;
  "letfun", LETFUN
]

}

rule token = parse
  "\010" | "\013" | "\013\010"
     { next_line lexbuf; token lexbuf }
| [ ' ' '\009' '\012' ] +
     { token lexbuf }
| [ '@' 'a'-'z' 'A'-'Z' ] (( [ '@' 'a'-'z' 'A'-'Z' '_' '\192'-'\214' '\216'-'\246' '\248'-'\255' '\'' '0'-'9' ] )*)
     { let s = Lexing.lexeme lexbuf in
	 try
	   Hashtbl.find keyword_table s
         with Not_found ->
	   if (not (!accept_arobase)) && (String.contains s '@') then
	     raise (Error("Illegal character", extent lexbuf));
           IDENT (s, extent lexbuf)
     }
| '\"'    
    { 
      clear_buffer ();
      string lexbuf;
      STRING (get_string (),extent lexbuf) } 

| ([ '0'-'9' ]) +
    { 
      try 
        INT (int_of_string(Lexing.lexeme lexbuf))
      with Failure _ ->
	raise (Error("Incorrect integer", extent lexbuf))
    }
| ([ '0'-'9' ]) + '.' ([ '0'-'9' ])+
     { FLOAT (float_of_string(Lexing.lexeme lexbuf)) }
| "(*" {
         comment lexbuf;
         token lexbuf
       }
| ',' { COMMA }
| '(' { LPAREN }
| ')' { RPAREN }
| '[' { LBRACKET }
| ']' { RBRACKET }
| '{' { LBRACE }
| '}' { RBRACE }
| '|' { BAR }
| ';' { SEMI }
| ':' { COLON }
| '!' { REPL }
| "<=" { LEQ }
| '=' { EQUAL }
| "<>" { DIFF }
| "&&" { AND }
| "||" { OR }
| '.' { DOT }
| "<=(" { EQUIVLEFT }
| ")=>" { EQUIVRIGHT } 
| "==>" { IMPLIES }
| '+' { ADD }
| '-' { SUB }
| '*' { MUL }
| '/' { DIV }
| '^' { POWER }
| '<' { READ }
| '>' { WRITE }
| "->" { MAPSTO }
| ":=" { DEF }
| '#' { COUNT }
| eof { EOF }	
| _ { raise (Error("Illegal character", extent lexbuf)) }

and comment = parse
| "*)" { }
| "\010" | "\013" | "\013\010"
     { next_line lexbuf; comment lexbuf }
| eof { }
| _ { comment lexbuf }

and string = parse 
| '\"' { () }
| '\\' ['\\' '\'' '"' 'n' 't' 'b' 'r']
      { 
        add_char (char_backslash (Lexing.lexeme_char lexbuf 1));
        string lexbuf
      }
| '\\' _
      { raise (Error("Illegal escape", extent lexbuf)) }
| eof 
      { raise (Error("Unterminated string", extent lexbuf)) }
| _ 
      { 
        add_char (Lexing.lexeme_char lexbuf 0);
        string lexbuf 
      }

and interactive_command = parse
| '\"'    
    { 
      clear_buffer ();
      string lexbuf;
      Com_elem (get_string ()) } 
| [ ' ' '\009' '\012' ] +
     { interactive_command lexbuf }
| [ ^ '\"' ' ' '\009' '\012' ';' ] +
     { Com_elem (Lexing.lexeme lexbuf) }
| ';' { Com_sep }
| eof { Com_end }
