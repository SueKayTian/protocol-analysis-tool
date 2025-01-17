(*************************************************************
 *                                                           *
 *  Cryptographic protocol verifier                          *
 *                                                           *
 *  Bruno Blanchet, Vincent Cheval, and Marc Sylvestre       *
 *                                                           *
 *  Copyright (C) INRIA, CNRS 2000-2017                      *
 *                                                           *
 *************************************************************)

(*

    This program is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details (in file LICENSE).

    You should have received a copy of the GNU General Public License
    along with this program; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA

*)
(** Types module declares types of the abstract syntax
   tree and of sets of messages.
   There are recursive dependencies between these types,
   that is why they are included in the same module.
   The type of processes has been moved to the module types.mli
   because it is needed in the environment values for letfun, and the
   environments are needed for terms in queries that cannot be
   expanded before process translation *)

open Types



(** {6 Correspondence queries} *)

type event =
    QSEvent of bool (** true when injective *) * term
  | QFact of predicate * term list
  | QNeq of term * term
  | QEq of term * term

type realquery = Before of event * hypelem list list

and hypelem =
    QEvent of event
  | NestedQuery of realquery

(** The type used for query *)
type query =
    PutBegin of bool * funsymb list (** [PutBegin(true, f)] when [f] is injective *)
  | RealQuery of realquery

type eventstatus =
    { mutable end_status : onestatus;
      mutable begin_status : onestatus }

(** Equivalence queries *)
type eq_query =
  | DestructorQuery
  | ChoiceQuery
  | NonInterfQuery of (Types.funsymb * Types.term list option) list
  | WeakSecret of Types.funsymb

(** Types of reduction steps, for trace reconstruction. An
  [int] is used to get the number of the reduced process in the list
  of processes.  *)
type reduc_type =
  | RNil of int (** [n] Process:  [0] *)

  | RPar of int (** [RPar(n)] Process [n]: parallel reduction [|] *)
  | RRepl of int * int (** [RRepl(n, cpn)] [n] process:  Reduction [!] [cpn] copies*)
  | RRestr of int * funsymb * term
  (** [RRestr(n, na, n')] [n] Process: New [na.f_name] creating a new name n' *)
  | RLet1 of int * pattern * term
  (** [RLet1(n, pat, t)] [n] process: [Let pat = t] succeeds *)
  | RLet2 of int * pattern * term
  (** [Rlet2(n, pat, t)] [n] process: [Let pat = t] fails *)
  | RInput of int * term * pattern * term * term
  (**[RInput(n, tc, pat, calc, mess_term)] [n] process: [In(tc, pat)]
     done with message [mess_term] *)
  | RInput2 of int * term * pattern * term * term
  (** Used only when the interactive mode is on. When the pattern matching failed *)
  | ROutput1 of int * term * term * term
  (** [ROutput1(n, tc, calc, t)] [n] process: [Out(tc, t)] done with calc -> t  *)
  | ROutput2 of int * term * term
  (**  [ROutput2(n, tc, t)] [n] process :[Out(tc, t)] destructor fails *)
  | RTest1 of int * term
  (** [RTest1(n,t)] [n] process: [If t] succeds*)
  | RTest2 of int * term
  (** [RTest2(n,t)] [n] process: [If t] fails *)
  | RTest3 of int * term
  (** [RTest3(n,t)] [n] process: [If t] destructor fails *)
  | REvent1 of int * term * bool
  (** [REvent1(n, t, b)] [n] process: [Event(t)] executed; b is true when an attack has been found*)
  | REvent2 of int * term
  (** [REvent2(n, t)] [n] process: [Event(t)] destructors fails or event blocks *)
  | RPhase of int
  (** [RPhase(n)] switch to phase [n] *)
  | RLetFilter1 of int * binder list * term list * fact
  (** [RLetFilter1(n, bl, f)]  [n] process: [let(b1,..,bm) suchthat f] executed ([bl = [b1,...,bm]]) *)
  | RLetFilter2 of int * binder list * fact
  (** [RLetFilter2(n, bl, f)]  [n] process: [let(b1,..,bm) suchthat f] destructor fails or
  [let... suchthat] blocks*)
  | RLetFilter3 of int * binder list * fact
  (** [RLetFilter3(n, bl, f)]  [n] process: [let(b1,..,bm) suchthat f] destructor fails or
  [let... suchthat] fails*)
  | RIO of int * term * pattern * int * term * term option * term * bool
  (** [RIO(n, tc', pat, no, tc, may_calc, t)] [In(tc', pat);Pn] reduces  with [out(tc,t);Pno] *)
  | RIO2 of int * term * pattern * int * term * term option * term * bool
  (** Reduction goes, but input fail *)
  | RInsert1 of int * term * bool
  (** [RInsert1(n, t), b] [Insert(t);Pn] when every thing is OK, b is true when an attack has been found *)
  | RInsert2 of int * term (** [Insert] when destructor fails *)
  | RGet of int * pattern * term * term
  (**  [RGet(n, pat, t, m)] [Get] when the match exists (first branch of Get taken)*)
  | RGet2 of int * pattern * term (** [Get] when the [else] branch is taken *)
  | RNamedProcess of int * string * term list
  | RInit (** Initial State *)

type name_param_info =
    arg_meaning * term * when_include

(**{6 Reduction and reduction of biprocess} *)

(**The 'a may be term (for reduction.ml) or term * term (for reduction_bipro.ml) *)

type 'a info =
    InputInfo of (binder * 'a) list * (term * 'a) list * 'a * name_param_info list * hypspec list *
                 ('a * (term * (binder * 'a) list * (term * 'a) list) option) list
	(** Channel name after decomposition of tuples,
	   Public set of values at last test,
	   Channel name,
	   name_params, occs,
	   list of possible messages, possibly with their recipe and their public status: the message after decomposition of tuples and the public set of values at last test.

	   Assume
	   [InputInfo(tc_list, oldpub, tc, name_params, occs, mess_list)].
	   - If [tc_list != []], the first element of [l] is not in [oldpub]
	   we check whether the first element of
	   [tc_list] is the part of public before [oldpub].
	   - If no,  [tc_list' = tc_list]
	   - If yes, we remove from the tail of [l] the first elements that
	   are in public, yielding [tc_list'].
	   We replace the cache with  [InputInfo(tc_list',public,...)],
	   If [tc_list'] is not empty, the channel is not public,
	   try to perform (Res I/O).
	   If [tc_list'] is empty, the channel is public,
	   try to perform (Res In).
      *)
  | OutputInfo of (binder * 'a) list * (term * 'a) list
	(** the channel name after decomposition of tuples:
               this is a list containing 'a, and the corresponding recipe
	       of type binder; the actual recipe will be stored in this
	       binder when it is known.
	   the public set of values at last test.
	   Invariant: if we have [OutputInfo(l,oldpub)],
           the first element of [l] is not [oldpub].

	   When testing this output, we check whether the first element of
	   [l] in is the part of public before oldpub.
	   - If no, we replace the cache with [OutputInfo(l,public)].
	   - If yes, we remove from the tail of [l] the first elements that
	   are in public, yielding [l']. If [l'] is not empty, we replace
	   the cache with [OutputInfo(l',public)]. If [l'] is empty,
	   we can execute the output: the channel is public.
	   *)
  | GetInfo of 'a list * 'a list
	(** the old contents of tables
	   the list of possible entries *)
  | Nothing

type 'a sub_proc =
    process * (name_param_info list) * (hypspec list) * (fact list) * ('a info)
      (**
      A process (always closed -- only bound variables can occur;
      no variable with link).
      - list of name_params (terms received as input + session ids),
      always closed -- no variables.
      - list of occurrences of inputs and replications already seen in the reduction
      - list of facts corresponding to already seen inputs -- no variables
      - cached info for inputs *)

(** Types of locations (attacker or process) for steps in trace reconstruction *)
type 'a loc_info =
    LocAttacker of term (* recipe used to compute a term at that location *)
  | LocProcess of int * 'a sub_proc

type weak_test =
    FailTest of term
  | EqTest of term * term

type 'a noninterf_test =
    ProcessTest of hypspec list * term list * (int * 'a sub_proc) option ref
    (**location where test found*)
  | InputProcessTest of hypspec list * term list * term(* message received by the input *) *
	(int * 'a sub_proc (*location of the input that makes the test*) *
	 'a loc_info (*location of the output that sends the message*)) option ref
  | ApplyTest of funsymb * ('a * term option ref) list
  | NIFailTest of 'a * term option ref (* recipe *)
  | CommTest of 'a(**input channel*) * 'a(**output channel*) *
	('a loc_info * 'a loc_info) option ref
	(** [CommTest(input_channel, output_channel, Some(input_location, output_location))]*)
  | NIEqTest of ('a * term option ref) * ('a * term option ref)


type 'a goal_t =
    Fact of fact * term list option ref (* the second component stores the recipes used to
                                           by the adversary to compute terms in the fact *)
  | WeakSecrGoal of (term * binder * term option ref (*recipe*)) list * weak_test * term * term
	(**  [WeakSecrGoal(l, t, w1, w2)] where [l] is the
          list of terms that the attacker has to know with the recipies to obtain them,
          with arbitrary variables
	  to store them, [t] is
	  the term that the attacker computes to test its guess,
	  [w1] is the weak secret that the attacker wants to guess,
	  [w2] is the symbol that represents the guess
	*)
  | NonInterfGoal of 'a noninterf_test
  | InjGoal of fact * term * int
        (** [InjGoal(f,sid',n)] The end event [f] to execute, the second session [sid'] in which
	    it should be executed, and the number [n] of times it has already been met *)
  | NoGoal (* for reduction_interact *)

type 'a reduc_state =
    {
      goal : 'a goal_t; (** goal to reach *)
      subprocess : 'a sub_proc list; (** process list *)
      public : (term * 'a) list; (** attacker knowledge, and the calculus that leads to it *)
      tables : 'a list; (** contents of tables *)
      prepared_attacker_rule : (predicate * (binder * 'a) list * (term * 'a)) list;
      (** attacker rules: predicate, hypothesis, conclusion *)
      io_rule : (int * fact list * hypspec list * term list * fact) list; (** process rules *)
                (** rule number, hypotheses, occurrence labels, name params, conclusion *)

      previous_state : ('a reduc_state) option; (** previous semantic state *)

      hyp_not_matched : (term option * fact) list;
      assumed_false : fact list list; (* Blocking facts that need to be assumed false to execute the considered trace,
					 to execute else branches of let...suchthat. 
					 More precisely, for each list of facts [f1; ..., fn] in [assumed_false],
					 we assume [not (f1 && ... && fn)]. *) 
      current_phase : int;
      comment : reduc_type  (** type of the reduction *)
    }

(** Indications of term occurrences that should be added to name_params *)
type term_occ =
      OTest of int
    | OLet of int
    | OInChannel of int
    | OEvent of int
    | OLetFilter of int

(** Type data for interact version of proverif *)
type data = {public_lst: string list; titles: string list; proc_llst: string list list}
