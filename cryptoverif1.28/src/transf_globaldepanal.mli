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
open Types

(* The "global_dep_anal" game transformation.
   This transformation can be called in two ways:
   - the normal game transformation, function main
   - as a subtransformation of "simplify", called from simplify.ml, function check_all_deps
   *)

(* Local advice *)
val advise : instruct list ref

(* [check_all_deps b0 init_proba_state g] is the entry point for calling 
   the dependency analysis from simplification.
   [b0] is the variable on which we perform the dependency analysis.
   [init_proba_state] contains collisions eliminated by before the dependency analysis,
   in previous passes of simplification.
   [g] is the full game to analyze. *)
val check_all_deps : binder ->
  simplify_internal_info_t *
    ((binderref * binderref) list * term * term list *
       repl_index list * repl_index list *
       repl_index list * term * term * binder *
       term list option * typet list) list -> 
	 game -> game option

(* [main b0 coll_elim g] is the entry point for calling
   the dependency analysis alone.
   [b0] is the variable on which we perform the dependency analysis.
   [coll_elim] is a list of occurrences, types or variable names 
   for which we allow eliminating collisions even if they are not [large].
   [g] is the full game to analyze.

   When calling [main], the terms and processes in the input game must be physically
   distinct, since [Terms.build_def_process] is called.  *)
val main : binder -> string list -> game_transformer
