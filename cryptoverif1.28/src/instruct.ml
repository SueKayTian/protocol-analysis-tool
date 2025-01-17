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
open Parsing_helper

(* For backtracking *)
exception Backtrack

let rec state_without_proof state =
  match state.prev_state with
    None -> state
  | Some(Proof _,_,_,s) -> state_without_proof s
  | Some(i,p,d,s) -> { state with prev_state = Some(i,p,d,state_without_proof s) }

let eq_list l1 l2 =
  (List.for_all (fun x -> List.memq x l1) l2) &&
  (List.for_all (fun x -> List.memq x l2) l1)

let has_common_elem l1 l2 =
  List.exists (fun x -> List.memq x l1) l2

let sa_rename_ins_updater b bl = function
    (ExpandIfFindGetInsert | Simplify _ | RemoveAssign(All) | 
     RemoveAssign(Minimal) | RemoveAssign(FindCond) | 
     MoveNewLet(MAll | MNoArrayRef | MLet | MNew | MNewNoArrayRef) | 
     Proof _ | InsertEvent _ | InsertInstruct _ | ReplaceTerm _ | MergeBranches |
     MergeArrays _ (* MergeArrays does contain variable names, but it is advised only when these variables have a single definition, so they are not modified by SArename *)) as x -> [x]
  | RemoveAssign (OneBinder b') ->
      if b' == b then
	List.map (fun b'' ->  RemoveAssign (OneBinder b'')) bl
      else
	[RemoveAssign (OneBinder b')]
  | SArenaming b' -> 
      if b' == b then
	 (* If b' == b, useless after SArenaming b *)
	[]
      else
	[SArenaming b']
  | MoveNewLet (MOneBinder b') -> 
      if b' == b then
	List.map (fun b'' -> MoveNewLet (MOneBinder b'')) bl
      else
	[MoveNewLet (MOneBinder b')]
  | GlobalDepAnal (b',l) ->
      if b' == b then
	List.map (fun b'' -> GlobalDepAnal (b'',l)) bl
      else
	[GlobalDepAnal (b',l)]
  | CryptoTransf(eq,VarList(bl',stop)) ->
      if List.memq b bl' then
	List.map (fun b'' -> CryptoTransf(eq, VarList(List.map (fun b' -> if b' == b then b'' else b') bl', stop))) bl
      else
	[CryptoTransf(eq,VarList(bl',stop))]
  | CryptoTransf(eq,Detailed(None,_)) ->
      [CryptoTransf(eq,Detailed(None,None))] (* term mapping cannot be preserved *)
  | CryptoTransf(eq,Detailed(Some(vmap,vl,stop), _)) ->
      if List.exists (fun (b',_) -> b'==b) vmap then
	List.map (fun b'' -> CryptoTransf(eq, Detailed(Some(
	   List.map (fun (b',r) -> if b' == b then (b'',r) else (b',r)) vmap, vl, stop), None))) bl
      else if List.memq b vl then
	List.map (fun b'' -> CryptoTransf(eq, Detailed(Some(vmap, List.map (fun b' -> if b' == b then b'' else b') vl, stop), None))) bl
      else
	[CryptoTransf(eq,Detailed(Some(vmap,vl,stop), None))]
	  
let compos_ins_updater a b = match a, b with
  None, x -> x
| x, None -> x
| Some f1, Some f2 -> Some (fun t -> List.concat (List.map f2 (f1 t)))

let apply_ins_updater ins_up i =
  match ins_up with
    None -> [i]
  | Some f -> f i

let apply_ins_updater_list ins_up l =
  match ins_up with
    None -> l
  | Some f -> List.concat (List.map f l)

let rec compos_sa_rename = function
    [] -> None
  | (DSArenaming(b,bl')::l) -> compos_ins_updater (Some (sa_rename_ins_updater b bl')) (compos_sa_rename l)
  | _::l -> compos_sa_rename l

let compos_transf f (g, proba, done_ins) =
  let (g', proba', done_ins') = f g in
  (g', proba' @ proba, done_ins' @ done_ins)

let execute g ins =
  let (g', proba, done_ins) = 
    match ins with
      ExpandIfFindGetInsert -> 
	compos_transf Transf_expand.expand_process (Transf_tables.reduce_tables g)
    | Simplify l -> Transf_simplify.simplify_main l g
    | GlobalDepAnal (b,l) -> Transf_globaldepanal.main b l g
    | MoveNewLet s -> Transf_move.move_new_let s g
    | RemoveAssign r -> Transf_remove_assign.remove_assignments r g
    | SArenaming b -> Transf_sarename.sa_rename b g
    | InsertEvent(s,occ) -> Transf_insert_event.insert_event occ s g
    | InsertInstruct(s,ext_s,occ,ext_o) -> 
	Transf_insert_replace.insert_instruct occ ext_o s ext_s g
    | ReplaceTerm(s,ext_s,occ,ext_o) ->
	Transf_insert_replace.replace_term occ ext_o s ext_s g 
    | MergeArrays(bll, m) ->
	Transf_merge.merge_arrays bll m g
    | MergeBranches ->
	Transf_merge.merge_branches g
    | CryptoTransf _ | Proof _ -> 
	Parsing_helper.internal_error "CryptoTransf/Proof unexpected in execute"
  in
  (g', proba, done_ins, compos_sa_rename done_ins)


let execute_state_basic state i =
  let tmp_changed = !Settings.changed in
  Settings.changed := false;
  print_string "Doing ";
  Display.display_instruct i;
  print_string "... "; flush stdout;
  let (g', proba, done_ins, ins_update) = execute state.game i in
  if !Settings.changed then
    begin
      print_string "Done.";
      print_newline()
    end
  else
    begin
      print_string "No change.";
      print_newline()
    end;
  if !Settings.debug_instruct then
    begin
      print_string " Resulting game:\n";
      Display.display_process g'.proc
    end;
  if !Settings.changed then
    begin
      g'.proc <- Terms.move_occ_process g'.proc;
      Invariants.global_inv g'.proc;
      ({ game = g';
	 prev_state = Some (i, proba, done_ins, state) }, ins_update)
    end
  else
    begin
      Settings.changed := tmp_changed;
      (state, None)
    end

let default_remove_assign() =
  let r = if !Settings.auto_remove_assign_find_cond then FindCond else Minimal in
  RemoveAssign(r)
      
let rec execute_state state = function
    SArenaming b ->
      (* Adding simplification after SArenaming *)
      let tmp_changed = !Settings.changed in
      Settings.changed := false;
      let (state', ins_updater) = execute_state_basic state (SArenaming b) in
      if !Settings.changed then 
	if !Settings.simplify_after_sarename then 
	  let (state'', ins_updater') = execute_state_basic state' (default_remove_assign()) in
	  let (state''', ins_updater'') = execute_state state'' (Simplify []) in
	  (state''', compos_ins_updater (compos_ins_updater ins_updater ins_updater') ins_updater'')
	else
	  (state', ins_updater)
      else
	begin
	  Settings.changed := tmp_changed;
	  (state', ins_updater)
	end
  | (Simplify l) as i ->
      (* Iterate Simplify (!Settings.max_iter_simplif) times *)
      let tmp_changed = !Settings.changed in
      Settings.changed := false;
      print_string "Doing ";
      Display.display_instruct i;
      print_string "... "; flush stdout;
      let rec iterate iter state =
	let (g', proba, done_ins, ins_updater) = execute state.game i in
	if !Settings.debug_instruct then
	  begin
	    print_string " Resulting game after one simplification pass:\n";
	    Display.display_process g'.proc
	  end;
	match done_ins with
	  [] ->
	    (* No change in this pass *)
	    print_string "Run simplify ";
            print_int ((!Settings.max_iter_simplif) - iter + 1);
	    print_string " time(s). Fixpoint reached.\n";
	    (state, None)
	| [DGlobalDepAnal _] ->
	    (* Global dependency analysis done; iterate simplification the same number of times *)
	    g'.proc <- Terms.move_occ_process g'.proc;
	    Invariants.global_inv g'.proc;
	    let state' =  
	      { game = g';
		prev_state = Some (i, proba, done_ins, state) }
	    in
	    let (state'', ins_updater') = iterate iter state' in
	    (state'', compos_ins_updater ins_updater ins_updater')
	| _ ->
	    (* Simplification done *)
	    g'.proc <- Terms.move_occ_process g'.proc;
	    Invariants.global_inv g'.proc;
	    let state' =  
	      { game = g';
		prev_state = Some (i, proba, done_ins, state) }
	    in
	    if iter != 1 then
	      let (state'', ins_updater') = iterate (iter-1) state' in
	      (state'', compos_ins_updater ins_updater ins_updater')
	    else
	      begin
		print_string "Run simplify ";
		print_int ((!Settings.max_iter_simplif) - iter + 1);
		print_string " time(s). Maximum reached.\n";
		(state', ins_updater)
              end
      in
      let result = iterate (!Settings.max_iter_simplif) state in
      (* Transfer the local advice of Globaldepanal to the global advice in Settings.advise *)
      List.iter (fun x -> Settings.advise := Terms.add_eq x (!Settings.advise)) (!Transf_globaldepanal.advise);
      Transf_globaldepanal.advise := [];

      if !Settings.changed then
	begin
	  print_string "Done.";
	  print_newline();
	  result
	end
      else
	begin
	  print_string "No change.";
	  print_newline();
	  Settings.changed := tmp_changed;
	  (state, None)
	end
  | i -> execute_state_basic state i

let rec execute_with_advise state i = 
  let tmp_changed0 = !Settings.changed in
  Settings.changed := false;
  Settings.advise := [];
  let (state', ins_update) = execute_state state i in
  if (!Settings.advise) != [] then
    (* Retry after executing the advise *)
    let tmp_changed = !Settings.changed in
    Settings.changed := false;
    if !Settings.debug_instruct then
      begin
	print_string "Trying advice ";
	Display.display_list Display.display_instruct (!Settings.advise);
	print_newline()
      end;
    let (state'', ins_update') = execute_list_with_advise state' (!Settings.advise) in
    if !Settings.changed then
      let (state3, ins_update'') = execute_list_with_advise state'' (apply_ins_updater ins_update' i) in
      (state3, compos_ins_updater ins_update (compos_ins_updater ins_update' ins_update''))
    else
      begin
	Settings.changed := tmp_changed0 || tmp_changed;
	(state', ins_update)
      end
  else
    begin
      Settings.changed := tmp_changed0 || (!Settings.changed);
      (state', ins_update)
    end

and execute_list_with_advise state = function
    [] -> (state, None)
  | (a::l) -> 
      let (state1, ins_update1) = execute_with_advise state a in
      let (state2, ins_update2) = execute_list_with_advise state1 (apply_ins_updater_list ins_update1 l) in
      (state2, compos_ins_updater ins_update1 ins_update2)

let execute_with_advise_last state i = 
  (* No need to update next instructions, so we can ignore the ins_updater *)
  let (state', _) = execute_with_advise state i in
  state'


let execute_display_advise state i =
  if !Settings.auto_advice then
    execute_with_advise_last state i 
  else
    let tmp_changed0 = !Settings.changed in
    Settings.changed := false;
    Settings.advise := [];
    let (state', _) = execute_state state i in
    if (!Settings.advise) != [] then
      begin
	print_string "Advised transformations ";
	Display.display_list Display.display_instruct (!Settings.advise);
	print_newline()
      end;
    Settings.changed := tmp_changed0 || (!Settings.changed);
    state'

type trans_res =
    CSuccess of state
  | CFailure of (equiv_nm * crypto_transf_user_info * instruct list) list

let move_new_let state =
  if !Settings.auto_move then
    execute_with_advise_last state (MoveNewLet MAll)
  else
    state

let remove_assign_no_sa_rename state =
  let tmp_auto_sa_rename = !Settings.auto_sa_rename in
  Settings.auto_sa_rename := false;
  let state' = execute_with_advise_last state (default_remove_assign()) in
  Settings.auto_sa_rename := tmp_auto_sa_rename;
  state'

let merge state =
  if !Settings.merge_branches then
    execute_with_advise_last state MergeBranches
  else
    state

let simplify state = merge (execute_with_advise_last (move_new_let (execute_with_advise_last (remove_assign_no_sa_rename state) (Simplify []))) (default_remove_assign()))

let expand_simplify state = simplify (execute_with_advise_last state ExpandIfFindGetInsert)

let display_failure_reasons failure_reasons =
  if failure_reasons == [] then
    begin
      print_string "."; print_newline()
    end
  else
    begin
      print_string ":"; print_newline()
    end;
  List.iter (fun (bl, failure_reason) ->
    if bl != [] then
      begin
	print_string "Random variables: ";
	Display.display_list (fun (b1,b2) -> Display.display_binder b1; print_string " -> "; Display.display_binder b2) bl;
	print_newline()
      end;
    Transf_crypto.display_failure_reason failure_reason
      ) failure_reasons

let crypto_transform no_advice equiv user_info state =
  print_string "Trying "; Display.display_instruct (CryptoTransf(equiv, user_info)); print_string "... "; flush stdout;
  let res = Transf_crypto.crypto_transform no_advice equiv user_info state.game in
  match res with
    TSuccess (proba,ins,g'') -> 
      if !Settings.debug_instruct then
	begin
	  Display.display_process state.game.proc;
	  print_string "Applying ";
	  Display.display_equiv_with_name equiv;
	  Display.display_with_user_info user_info;
	  print_string " succeeds. Resulting game:\n";
	  Display.display_process g''.proc
	end
      else
	print_string "Succeeded.\n"; 
      flush stdout;
      (* Always expand FindE *)
      g''.proc <- Terms.move_occ_process g''.proc;
      Invariants.global_inv g''.proc;
      CSuccess (simplify { game = g''; 
			   prev_state = Some (CryptoTransf(equiv, user_info), proba, ins, state) })
  | TFailure (l,failure_reasons) ->
      if !Settings.debug_instruct then
	begin
	  Display.display_process state.game.proc;
	  print_string "Applying ";
	  Display.display_equiv_with_name equiv;
	  Display.display_with_user_info user_info;
	  print_string " failed";
	  display_failure_reasons failure_reasons;
	  if l != [] then print_string "Suggestions: \n";
	  List.iter (fun (_, user_info, to_do) ->
	    Display.display_user_info user_info;
	    print_string ", after executing ";
	    Display.display_list Display.display_instruct to_do;
	    print_newline()
	      ) l
	end
      else
	begin
	  print_string "Failed";
	  display_failure_reasons failure_reasons
	end;
      CFailure l

let get_var_list = function
    VarList(l,_) -> l
  | Detailed(vmopt,_) ->
      match vmopt with
	None -> []
      | Some (vm,vl,_) -> vl @ (List.map fst vm) 
	
let rec execute_crypto_list continue = function
    [] -> continue (CFailure [])
  | ((equiv, user_info, to_do), state, first_try)::l ->
      (* Try after executing the advice *)
      Settings.changed := false;
      if to_do == [] then
        (* When no advice is given and it's not the first time the transfo is tried, apply the crypto transformation without advice *)
	match crypto_transform ((not first_try) || (!Settings.no_advice_crypto)) equiv user_info state with
	  CSuccess state'' -> 
	    begin
	      try
		continue (CSuccess state'')
	      with Backtrack ->
		if !Settings.backtrack_on_crypto then
	          (* Filter the choices to avoid considering too many similar choices *)
		  let l = List.filter (fun ((equiv', user_info', _), _, _) -> 
		    equiv' != equiv || not (has_common_elem (get_var_list user_info') (get_var_list user_info))) l
		  in
		  (*
		  print_string "Just tried\n";
		  Display.display_instruct (CryptoTransf(equiv, bl_assoc));
		  print_string "\nContinuing with:\n";
		  List.iter (fun ((equiv, bl_assoc, _), _, _) -> Display.display_instruct (CryptoTransf(equiv, bl_assoc)); print_newline()) l;
		  print_string "End of list\n";
		  *)
		  if l = [] then raise Backtrack;
		  execute_crypto_list continue (List.map (fun (tr, st, first_try) -> (tr, state_without_proof st, first_try)) l)
		else
		  raise Backtrack
	    end
	| CFailure l' -> execute_crypto_list continue ((List.map (fun x -> (x, state, false)) l') @ l) 
      else
	let (state', ins_updater) = execute_list_with_advise state to_do in
	if !Settings.changed then
	  let l_crypto_transf = apply_ins_updater ins_updater (CryptoTransf(equiv, user_info)) in
	  execute_crypto_list continue ((List.map (function
	      CryptoTransf(equiv, user_info) -> ((equiv, user_info, []), state', true)
	    | _ -> Parsing_helper.internal_error "The result of an ins_updater on CryptoTransf should be a list of CryptoTransf") l_crypto_transf) @ l)
	else
	  execute_crypto_list continue l
	

let rec execute_any_crypto_rec continue state = function
    [] -> continue (CFailure [])
  | (((_,_,_,_,opt,_),_) as equiv::equivs) ->
      match opt with
	ManualEqopt -> 
          (* This equivalence should be applied only manually, and we are in automatic mode, so skip it *) 
	  execute_any_crypto_rec continue state equivs
      |	_ ->
      match crypto_transform (!Settings.no_advice_crypto) equiv (VarList([],false)) state with
	CSuccess state' -> 
	  begin
	    try
	      continue (CSuccess state')
	    with Backtrack ->
	      if !Settings.backtrack_on_crypto then
		begin
		  (*
		  print_string "Just tried equivalence\n";
		  Display.display_equiv equiv;
		  print_string "\nContinuing with equivalences:\n";
		  List.iter Display.display_equiv equivs;
		  print_string "End of list\n";
		  *)
		  execute_any_crypto_rec continue (state_without_proof state) equivs
		end
	      else
		raise Backtrack
	  end
      | CFailure l -> 
	  execute_any_crypto_rec (function  
	      CSuccess state' -> continue (CSuccess state')
	    | CFailure l' -> continue (CFailure (l @ l'))) state equivs

let rec issuccess_with_advise state = 
  Settings.advise := [];
  let (proved_queries, is_done) = Success.is_success state in
  let state' = 
    if proved_queries != [] then
      { game = state.game;
	prev_state = Some (Proof proved_queries, [], [], state) }
    else
      state
  in
  if is_done then
    (state', true)
  else 
    let (state'', is_done'') = 
      if (!Settings.advise) != [] then
        (* Retry after executing the advise *)
	let tmp_changed = !Settings.changed in
	Settings.changed := false;
	if !Settings.debug_instruct then
	  begin
	    print_string "Trying advice ";
	    Display.display_list Display.display_instruct (!Settings.advise);
	    print_newline()
	  end;
	let (state'',_) = execute_list_with_advise state' (!Settings.advise) in
	if !Settings.changed then
	  let (state_after_success, _) as result = issuccess_with_advise state'' in
	  if state_after_success == state'' then
	    (* Nothing was proved by the call to issuccess_with_advise,
	       undo the advised transformations *)
	    (state', false)
	  else
	    (* Something was proved by issuccess_with_advise, keep it *)
	    result
	else
	  begin
	    Settings.changed := tmp_changed;
	    (state', false)
	  end
      else
	(state', false)
    in
    if (state'' == state') && (proved_queries == []) && (is_done'' == false) then
      (state, false) (* Forget useless changes *)
    else
      (state'', is_done'')

let rec is_full_state query_list g state =
  if state.game == g then
    true
  else
    match state.prev_state with
      None -> Parsing_helper.internal_error "Game not found"
    | Some(_, proba, _, s') ->
        (List.for_all (is_full_proba query_list) proba) &&
	(is_full_state query_list g s')

and is_full_proba query_list = function
    SetProba _ -> true
  | SetEvent(f,g,poptref) ->
      match !poptref with
	Some _ -> true
      |	None -> false

let display_state tex state =
  (* AbsentQuery is proved in the current state, if present *)
  let old_queries = state.game.current_queries in
  let state' = 
    let eq_queries = List.filter (function (AbsentQuery, _),_,_ -> true | _ -> false) state.game.current_queries in
    if eq_queries == [] then
      state
    else
      begin
	state.game.current_queries <-
	   List.map (function 
	       (AbsentQuery, g), poptref, popt -> 
		 let proof = Some([], state) in
		 if is_full_state old_queries g state then 
		   poptref := proof;
		 (AbsentQuery, g), poptref, proof
	     | q -> q) old_queries;
	{ game = state.game;
	  prev_state = Some (Proof (List.map (fun (q, _, _) -> (q, [])) eq_queries), [], [], state) }
      end
  in
  (* Display the state *)
  Display.display_state state';
  if tex && ((!Settings.tex_output) <> "") then
    Displaytex.display_state state';
  (* Undo the proof of AbsentQuery *)
  state.game.current_queries <- old_queries;
  List.iter (function 
      (AbsentQuery, g), poptref, popt -> poptref := None
    | _ -> ()) old_queries

let rec display_short_state state =
  match state.prev_state with
    None -> ()
  | Some(CryptoTransf _ as i, _, _, s) ->
      display_short_state s;
      Display.display_instruct i;
      print_newline()
  | Some(_,_,_,s) ->
      display_short_state s

(* Insertion sort; used to sort the equivalences according to their priority.
   The elements of same priority are grouped in a list *)

let get_prio ((_,_,_,_,opt,_),_) =
  match opt with
    StdEqopt | ManualEqopt -> 0
  | PrioEqopt n -> n
    
let rec insert_elem a = function
    [] -> [[a]]
  | (l1::l) ->
      match l1 with
	[] -> Parsing_helper.internal_error "Empty list unexpected in insert_elem"
      |	first_l1::_ ->
	  let prio_l1 = get_prio first_l1 in
	  let prio_a = get_prio a in
	  if prio_l1 = prio_a then (a::l1)::l else
	  if prio_l1 < prio_a then l1 :: (insert_elem a l) else
	  [a]::l1::l
	  
let rec insert_sort sorted = function
    [] -> sorted
  | (a::l) ->
      let sorted' = insert_sort sorted l in
      (* Insert a into sorted' *)
      insert_elem a sorted'


let rec execute_any_crypto_rec1 state =
  let (state', is_done) =  issuccess_with_advise state in
  if is_done then
    begin
      print_string "===================== Proof starts =======================\n";
      display_state true state';
      (CSuccess state', state)
    end
  else
    let equiv_list = insert_sort [] (!Settings.equivs) in
    let rec apply_equivs = function
	[] -> 
	  if !Settings.backtrack_on_crypto then
	    begin
	      print_string "Examined sequence:\n";
	      display_short_state state';
	      print_string "Backtracking...\n";
	      raise Backtrack
	    end
	  else
	    (CFailure [], state')
      |	lequiv::rest_equivs ->
	  execute_any_crypto_rec (function
	      CSuccess state'' -> execute_any_crypto_rec1 state''
	    | CFailure l -> execute_crypto_list (function 
		  CFailure _ -> 
		    apply_equivs rest_equivs
		| CSuccess state''' ->
		    execute_any_crypto_rec1 state''') (List. map (fun x -> (x, state', false)) l)) state' lequiv
    in
    apply_equivs equiv_list

let execute_any_crypto state =
  (* Always begin with find/if/let expansion *)
  try
    let (res, state') = execute_any_crypto_rec1 (expand_simplify state) in
    begin
      match res with
	CFailure _ -> 
	  print_string "===================== Proof starts =======================\n";
	  display_state true state'
      |	CSuccess _ -> ()
    end;
    res
  with Backtrack ->
    display_state true state;
    CFailure []
	    
(* Interactive prover *)

exception End of state

let add accu b =
  let s = Display.binder_to_string b in
  if not (Hashtbl.mem accu s) then
    Hashtbl.add accu s b

let rec find_binders_term accu t =
  match t.t_desc with
    Var(_,l) | FunApp(_,l) ->
      List.iter (find_binders_term accu) l
  | ReplIndex _ -> ()
  | TestE(t1,t2,t3) ->
      find_binders_term accu t1;
      find_binders_term accu t2;
      find_binders_term accu t3
  | FindE(l0,t3,_) ->
      List.iter (fun (bl,def_list,t1,t2) ->
	List.iter (fun (b,_) -> add accu b) bl;
        List.iter (find_binders_br accu) def_list;
	find_binders_term accu t1;
	find_binders_term accu t2) l0;
      find_binders_term accu t3
  | ResE(b,t) ->
      add accu b;
      find_binders_term accu t
  | EventAbortE _ -> ()
  | LetE(pat, t1, t2, topt) ->
      find_binders_pat accu pat;
      find_binders_term accu t1;
      find_binders_term accu t2;
      begin
      match topt with
	None -> ()
      |	Some t3 -> find_binders_term accu t3
      end
  | EventE(t,p) ->
      find_binders_term accu t;
      find_binders_term accu p
  | GetE _|InsertE _ -> Parsing_helper.internal_error "Get/Insert should not appear here"
      
and find_binders_pat accu = function
    PatVar b -> add accu b
  | PatTuple(_,l) -> List.iter (find_binders_pat accu) l
  | PatEqual t -> find_binders_term accu t

and find_binders_br accu (b,l) =
  List.iter (find_binders_term_def_list accu) l;
  add accu b

and find_binders_term_def_list accu t =
  match t.t_desc with
    Var(b,l) -> 
      List.iter (find_binders_term_def_list accu) l;
      add accu b
  | FunApp(_,l) ->
      List.iter (find_binders_term_def_list accu) l
  | ReplIndex _ -> ()
  | _ -> 
      Parsing_helper.internal_error "if/let/find/new forbidden in def_list"

let rec find_binders_rec accu p =
  match p.i_desc with
    Nil -> ()
  | Par(p1,p2) -> 
      find_binders_rec accu p1;
      find_binders_rec accu p2
  | Repl(b,p) -> find_binders_rec accu p
  | Input((c, tl),pat,p) ->
      List.iter (find_binders_term accu) tl;
      find_binders_pat accu pat;
      find_binders_reco accu p

and find_binders_reco accu p =
  match p.p_desc with
    Yield | EventAbort _ -> ()
  | Restr(b,p) -> 
      add accu b;
      find_binders_reco accu p
  | Test(t,p1,p2) ->
      find_binders_term accu t;
      find_binders_reco accu p1;
      find_binders_reco accu p2
  | Find(l0,p2,_) ->
      List.iter (fun (bl,def_list,t,p1) ->
	List.iter (fun (b,_) -> add accu b) bl;
        List.iter (find_binders_br accu) def_list;
	find_binders_term accu t;
	find_binders_reco accu p1) l0;
      find_binders_reco accu p2
  | Output((c, tl),t2,p) ->
      List.iter (find_binders_term accu) tl;      
      find_binders_term accu t2;
      find_binders_rec accu p
  | Let(pat, t, p1, p2) ->
      find_binders_pat accu pat;
      find_binders_term accu t;
      find_binders_reco accu p1;
      find_binders_reco accu p2
  | EventP(t,p) ->
      find_binders_term accu t;
      find_binders_reco accu p
  | Get _|Insert _ -> Parsing_helper.internal_error "Get/Insert should not appear here"

let find_binders game =
  let accu = Hashtbl.create 7 in
  find_binders_rec accu game;
  accu 

let find_binder binders (s,ext) =
  try
    Hashtbl.find binders s
  with Not_found -> 
    raise (Error("Binder " ^ s ^ " not found", ext))

let rec find_funsymb f t =
  match t.t_desc with
    Var(b,l) -> List.exists (find_funsymb f) l
  | FunApp(f',l) -> (f = f'.f_name) || (List.exists (find_funsymb f) l)
  | ReplIndex _ -> false
  | _ -> Parsing_helper.internal_error "If / find / let should not occur in left members of equivalences"

let rec find_funsymb_fg f = function
    ReplRestr(_,_,l) -> List.exists (find_funsymb_fg f) l
  | Fun(_,_,r,_) -> find_funsymb f r

let rec find_proba f = function
    Proba (p,_) -> f = p.prname
  | Count _ | OCount _ | Cst _ | Zero | Card _ | AttTime | Time _ 
  | ActTime _ | Maxlength _ |  TypeMaxlength _ | EpsFind | EpsRand _ 
  | PColl1Rand _ | PColl2Rand _ -> false
  | Add(x,y) | Sub(x,y) | Mul(x,y) | Div(x,y) -> (find_proba f x) || (find_proba f y)
  | Max(l) | Length(_,l) -> List.exists (find_proba f) l

let find_equiv f ((n,lm,_,set,_,_),_) =
  (List.exists (fun (fg, _) -> find_funsymb_fg f fg) lm) ||
  (List.exists (function 
      SetProba r -> find_proba f r
    | SetEvent(e,_,_) -> f = e.f_name) set)

let find_equiv_by_name f ((n,_,_,_,_,_),_) =
  match n with
    NoName -> false
  | CstName (s,_) -> f = s
  | ParName ((s1,_),(s2,_)) -> f = (s1 ^ "(" ^ s2 ^ ")")

let rec find_list f = function
    [] -> raise Not_found
  | (a::l) ->
      try
	f a
      with Not_found ->
	find_list f l
	
let rec find_oracle_fg s = function
    Fun(n,_,res,_) -> if s = n.cname then res else raise Not_found
  | ReplRestr(_,_,l) -> find_list (find_oracle_fg s) l
	
let find_oracle (s,ext) ((_,lm,_,_,_,_),_) =
  try
    find_list (fun (a,_) -> find_oracle_fg s a) lm
  with Not_found ->
    raise (Error("Oracle " ^ s ^ " not found in equivalence", ext))

let rec find_restr_fg s = function
    Fun _ -> raise Not_found
  | ReplRestr(_,restr,l) ->
      try
	find_list (fun (b,_) ->
	  if Display.binder_to_string b = s then b else raise Not_found) restr
      with Not_found ->
	find_list (find_restr_fg s) l
    
let find_restr (s,ext) ((_,lm,_,_,_,_),_) =
  try 
    find_list (fun (a,_) -> find_restr_fg s a) lm
  with Not_found ->
    raise (Error("Random variable " ^ s ^ " not found in equivalence", ext))
    
let do_equiv ext equiv (s,ext_s) state = 
  (* @ is not accepted in identifiers when parsing the initial file,
     but CryptoVerif creates variables with @, so I accept @ here. *)
  Parsing_helper.accept_arobase := true;
  let lexbuf = Lexing.from_string s in
  let parsed_user_info = 
    try 
      if (!Settings.front_end) == Settings.Channels then 
	Parser.cryptotransfinfo Lexer.token lexbuf
      else
	Oparser.cryptotransfinfo Olexer.token lexbuf
    with
      Parsing.Parse_error -> raise (Error("Syntax error", combine_extent ext_s (extent lexbuf)))
    | Error(s,ext) -> raise (Error(s, combine_extent ext_s ext))

  in
  match parsed_user_info with
    Ptree.PRepeat ->
      let rec repeat_crypto equiv state = 
	match crypto_transform (!Settings.no_advice_crypto) equiv (VarList([],false)) state with
	  CSuccess state' -> repeat_crypto equiv state'
	| CFailure l -> 
	    execute_crypto_list (function 
		CSuccess state'' -> repeat_crypto equiv state''
	      | CFailure _ -> print_string "Done all possible transformations with this equivalence.\n"; state) (List.map (fun x -> (x, state, false)) l) 
      in
      repeat_crypto equiv state
  | _ ->
      let user_info =
	match parsed_user_info with
	  Ptree.PRepeat -> Parsing_helper.internal_error "PRepeat should have been handled earlier"
	| Ptree.PVarList(lb, stop) -> 
           (* When the list of binders lb ends with a ".", do not add more binders
              automatically *)
	    let binders = find_binders state.game.proc in	      	  
	    let lb' = List.map (find_binder binders) lb in
	    VarList(lb',stop)
	| Ptree.PDetailed l ->
	    let binders = find_binders state.game.proc in	      	  
	    let var_mapping = ref None in
	    let term_mapping = ref None in
	    List.iter (function
		Ptree.PVarMapping((id,ext), map, stop) ->
		  if id <>"variables" then
		    raise (Error ("\"variables\" expected", ext));
		  if (!var_mapping) != None then
		    raise (Error ("Variable mapping already set", ext));
		  var_mapping := Some (List.fold_right (fun (id_g,id_equiv) accu ->
		    let v_g = find_binder binders id_g in
		    let v_equiv = find_restr id_equiv equiv in
		    if v_g.btype != v_equiv.btype then
		      raise (Error ("Variable " ^ (Display.binder_to_string v_g) ^ 
				    " should have the same type as " ^ 
				    (Display.binder_to_string v_equiv), snd id_g));
		    if List.exists (fun (v_g', _) -> v_g == v_g') accu then
		      raise (Error ("Variable " ^ (Display.binder_to_string v_g) ^ 
				    " mapped several times", snd id_g));
		    (v_g, v_equiv)::accu) map [], [], stop)
	      | Ptree.PTermMapping((id,ext),map,stop) ->
		  if id <>"terms" then
		    raise (Error ("\"terms\" expected", ext));
		  if (!term_mapping) != None then
		    raise (Error ("Term mapping already set", ext));
		  term_mapping := Some (List.map (fun (occ,id_oracle) ->
		    (occ, find_oracle id_oracle equiv)) map, stop)
		       ) l;
	    Detailed (!var_mapping, !term_mapping)
      in
      match crypto_transform (!Settings.no_advice_crypto) equiv user_info state with
	CSuccess state' -> state'
      | CFailure l -> 
	  if !Settings.auto_advice then
	    execute_crypto_list (function 
	      CSuccess state'' -> state''
	    | CFailure _ -> raise (Error ("Cryptographic transformation failed", ext))) (List.map (fun x -> (x, state, false)) l) 
	  else
	    begin
	      if l != [] then print_string "Failed. Suggestions: \n";
	      List.iter (fun (_, user_info, to_do) ->
		Display.display_user_info user_info;
		print_string ", after executing ";
		Display.display_list Display.display_instruct to_do;
		print_newline()
		  ) l;
	      raise (Error ("Cryptographic transformation failed", ext))
	    end


let rec undo ext state n =
  if n <= 0 then 
    state
  else
  match state.prev_state with
    None -> 
      raise (Error("Could not undo more steps than those already done", ext))
  | Some (ExpandIfFindGetInsert,_,_, { prev_state = None }) ->
      raise (Error("Cannot undo the first expansion", ext))
  | Some (ExpandIfFindGetInsert,_,_,_) ->
      Parsing_helper.internal_error "ExpandIfFindGetInsert should occur only as first instruction"
  | Some (_,_,_,state') -> undo ext state' (n-1)

let rec concat_strings = function
    [] -> ""
  | [a,_] -> a
  | ((a, _)::l) -> a ^ " " ^ (concat_strings l)

let get_ext = function
    [] -> dummy_ext
  | (_,ext)::_ -> ext

let help() =
  print_string (
  "List of available commands\n" ^
  "remove_assign useless        : remove useless assignments\n" ^
  "remove_assign binder <ident> : remove assignments on variable <ident>\n" ^
  "remove_assign all            : remove all assignments (not recommended)\n" ^
 (if (!Settings.front_end) == Settings.Channels then
  "move all                     : move all \"new\" and \"let\" down in the game\n" ^
  "move noarrayref              : move \"new\" and \"let\" without array references down in the game\n" ^
  "move random                  : move all \"new\" down in the game\n" ^
  "move random_noarrayref       : move \"new\" without array references down in the game\n" ^
  "move assign                  : move all \"let\" down in the game\n" ^
  "move binder <ident>          : move \"new <ident>\" or \"let <ident>\" down in the game\n"
  else
  "move all                     : move all \"<-R\" and \"<-\" down in the game\n" ^
  "move noarrayref              : move \"<-R\" and \"<-\" without array references down in the game\n" ^
  "move random                  : move all \"<-R\" down in the game\n" ^
  "move random_noarrayref       : move \"<-R\" without array references down in the game\n" ^
  "move assign                  : move all \"<-\" down in the game\n" ^
  "move binder <ident>          : move \"<ident> <-R\" or \"<ident> <-\" down in the game\n") ^
  "move array <ident>           : move the generation of the random <ident> to its first usage\n" ^
  "SArename <ident>    : rename several definitions of <ident> to distinct names\n" ^
  "global_dep_anal <ident>      : global dependency analysis on <ident>\n" ^
  "crypto                       : apply a cryptographic transformation\n" ^
  "(can be used alone or with a specifier of the transformation; see the manual)\n" ^
  "simplify                     : simplify the game\n" ^
  "simplify coll_elim <locations> : simplify the game, allowing collision elimination at <locations> (variables, types, occurrences)\n" ^
  "all_simplify                 : remove_assign useless, simplify, move all\n" ^
  "insert_event <ident> <occ>   : insert an event <ident> at occurrence <occ>\n" ^
  "insert <occ> <ins>           : insert instruction <ins> at occurrence <occ>\n" ^
  "replace <occ> <term>         : replace term at occurrence <occ> with <term> (when equal)\n" ^
  "merge_arrays <ident> ...     : merge all given variables\n" ^
  "merge_branches               : merge find branches\n" ^
  "success                      : check the desired properties\n" ^
  "show_game                    : show the current game\n" ^
  "show_game occ                : show the current game with occurrences\n" ^
  "show_state                   : show the sequence of games up to now\n" ^
  "show_facts <occ>             : show the facts that hold at program point <occ>\n" ^
  "out_game <filename>          : output the current game to <filename>\n" ^
  "out_game <filename> occ      : output the current game with occurrences to <filename>\n" ^
  "out_state <filename>         : output the sequence of games up to now to <filename>\n" ^
  "out_facts <filename> <occ>   : output the facts that hold at program point <occ> to <filename>\n" ^
  "auto                         : try to terminate the proof automatically\n" ^
  "set <param> = <value>        : set the value of various parameters\n" ^
  "allowed_collisions <formulas>: determine when to eliminate collisions\n" ^
  "undo                         : undo the last transformation\n" ^
  "undo <n>                     : undo the last n transformations\n" ^
  "restart                      : restart from the initial game\n" ^
  "quit                         : quit interactive mode\n" ^
  "help                         : display this help message\n" ^
  "?                            : display this help message\n")

let map_param (s,ext) ext_s =
  match s with
    "noninteractive" -> Settings.psize_NONINTERACTIVE
  | "passive" -> Settings.psize_PASSIVE
  | "small" -> Settings.psize_DEFAULT
  | _ -> (* option "size<n>" where <n> is an integer *)
      try
	if (String.sub s 0 4) <> "size" then raise Not_found;
	int_of_string (String.sub s 4 (String.length s - 4))
      with _ ->
	raise (Error("Unknown parameter size " ^ s, Parsing_helper.combine_extent ext_s ext))

let map_type (s,ext) ext_s =   
  try
    Settings.parse_type_size s 
  with Not_found ->
    raise (Error("Unknown type size " ^ s, Parsing_helper.combine_extent ext_s ext))

let rec interpret_command interactive state = function
    ("remove_assign", ext1)::l ->
      begin
	match l with
	  [("useless", _)] -> execute_display_advise state (RemoveAssign Minimal)
	| [("findcond", _)] -> execute_display_advise state (RemoveAssign FindCond)
	| [("all", _)] -> execute_display_advise state (RemoveAssign All)
	| [("binder",_); id] -> 
	    let binders = find_binders state.game.proc in
	    execute_display_advise state (RemoveAssign (OneBinder (find_binder binders id)))
	| _ -> 
	    raise (Error("Allowed options for remove_assign are useless, all, binder x", ext1))
      end
  | ("move",ext1)::l ->
      begin
	match l with
	  [("all",_)] -> execute_display_advise state (MoveNewLet MAll)
	| [("noarrayref",_)] -> execute_display_advise state (MoveNewLet MNoArrayRef)
	| [("random",_)] -> execute_display_advise state (MoveNewLet MNew)
	| [("random_noarrayref",_)] -> execute_display_advise state (MoveNewLet MNewNoArrayRef)
	| [("assign",_)] -> execute_display_advise state (MoveNewLet MLet)
	| [("binder",_); id] ->
	    let binders = find_binders state.game.proc in	      
	    execute_display_advise state (MoveNewLet (MOneBinder (find_binder binders id)))
	| [("array",_); ((s,ext2) as id)] ->
	    begin
	      let binders = find_binders state.game.proc in	      
	      let b = find_binder binders id in
	      if not (Proba.is_large b.btype) then
		raise (Error("Transformation \"move array\" is allowed only for large types", ext2));
 	      if (b.btype.toptions land Settings.tyopt_CHOOSABLE) == 0 then
		raise (Error("Transformation \"move array\" is allowed only for fixed, bounded, or nonuniform types",ext2));
	      try
		let equiv = List.assq b.btype (!Settings.move_new_eq) in
		match crypto_transform (!Settings.no_advice_crypto) equiv (VarList([b],true)) state with
		  CSuccess state' -> state'
		| CFailure l -> 
		    raise (Error ("Transformation \"move array\" failed", ext1))
	      with Not_found ->
		raise (Error("Transformation for \"move array\" not found, perhaps the macro move_array_internal_macro is not defined in your library", ext2))
	    end
	| _ -> raise (Error("Allowed options for move are all, noarrayref, random, random_noarrayref, assign, and binder x", ext1))
      end
  | ["simplify",_] ->
      execute_display_advise state (Simplify [])
  | ("simplify", _) :: ("coll_elim", _) :: l ->
      execute_display_advise state (Simplify (List.map fst l))
  | [("insert_event",_); (s,ext1); (occ_s,ext2)] ->
      begin
	try
	  if String.length s = 0 then raise Not_found;
	  if (s.[0] < 'A' || s.[0] >'Z') && (s.[0] < 'a' || s.[0] > 'z') then raise Not_found;
	  for i = 1 to String.length s - 1 do
	    if s.[i] <> '\'' && s.[i] <> '_' && (s.[i] < 'A' || s.[i] >'Z') && (s.[i] < 'a' || s.[0] > 'z') && (s.[i] < '\192' || s.[i] > '\214') && (s.[i] < '\216' || s.[i] > '\246') && (s.[i] < '\248') && (s.[i] < '0' && s.[i] > '9') then raise Not_found;
	  done;
	  let occ = int_of_string occ_s in
	  execute_display_advise state (InsertEvent(s,occ))
	with 
	  Not_found ->
	    raise (Error(s ^ " should be a valid identifier: start with a letter, followed with letters, accented letters, digits, underscores, quotes", ext1))
	| Failure _ ->
	    raise (Error("occurrence " ^ occ_s ^ " should be an integer", ext2))
	| Error(mess,_) ->
	    (* Errors for insert_event always concern the occurrence *)
	    raise (Error(mess, ext2))
      end
  | ("insert",_) :: (occ_s,ext2) :: (((_, ext1)::_) as r) ->
      begin
	try
	  let ins_s = concat_strings r in
	  let occ = int_of_string occ_s in
	  execute_display_advise state (InsertInstruct(ins_s,ext1,occ,ext2))
	with Failure _ ->
	  raise (Error("occurrence " ^ occ_s ^ " should be an integer", ext2))	  
      end
  | ("replace",_) :: (occ_s,ext2) :: (((_, ext1)::_) as r) ->
      begin
	try
	  let ins_s = concat_strings r in
	  let occ = int_of_string occ_s in
	  execute_display_advise state (ReplaceTerm(ins_s,ext1,occ,ext2))
	with Failure _ ->
	  raise (Error("occurrence " ^ occ_s ^ " should be an integer", ext2))	  
      end
  | ("merge_arrays",ext) :: r ->
      begin
	let binders = find_binders state.game.proc in
	if List.length r < 2 then 
	  raise (Error("You should give at least two variables to merge", ext));
	let rec anal_r accu = function
	    [] -> [List.rev accu]
	  | (",", ext)::r ->
	      (List.rev accu) :: (anal_r [] r)
	  | ((s, ext2)as id)::r ->
	      let b = (find_binder binders id, ext2) in
	      anal_r (b::accu) r
	in
	let bl = anal_r [] r in
	let fl = List.hd bl in
	if List.length fl < 2 then
	  raise (Error("You should give at least two variables to merge", ext));
	List.iter (fun al ->
	  if List.length al != List.length fl then
	    raise (Error("All lists of variables to merge should have the same length", ext))) bl;
	execute_display_advise state (MergeArrays(bl, MCreateBranchVar))
      end
  | ["merge_branches",_] ->
      execute_display_advise state MergeBranches
  | ["SArename",_;id] ->
      let binders = find_binders state.game.proc in	      
      execute_display_advise state (SArenaming (find_binder binders id))
  | ["global_dep_anal",_;id] ->
      let binders = find_binders state.game.proc in	      
      execute_display_advise state (GlobalDepAnal (find_binder binders id, []))
  | ("global_dep_anal",_) :: id :: ("coll_elim", _) :: l ->
      let binders = find_binders state.game.proc in	      
      execute_display_advise state (GlobalDepAnal (find_binder binders id, List.map fst l))
  | ["all_simplify",_] ->
      simplify state
  | ("crypto",ext1)::r ->
      begin
	let (eq_name_opt, possible_equivs, binders) =
	  match r with
	    [] -> (None, !Settings.equivs, [])
	  | ((n1, _) :: ("(",_) :: (n2,_) :: (")", _) :: lb) -> 
	      let s = n1 ^ "(" ^ n2 ^ ")" in
	      let eq_list = List.filter (find_equiv_by_name s) (!Settings.equivs) in
	      (Some s, eq_list, lb)
	  | (s, s_ext)::lb ->
	      try 
		(Some s, [List.nth (!Settings.equivs) (int_of_string s - 1)], lb)
	      with 
		Failure "nth" | Invalid_argument "List.nth" ->
		  raise (Error("Equivalence number " ^ s ^ " does not exist", s_ext))
	      |	Failure _ -> 
		  let eq_list = List.filter (find_equiv_by_name s) (!Settings.equivs) in
		  if eq_list = [] then
		    (* if the equivalence is not found by its name, try the old way of finding it,
		       by function symbol or probability name *)
		    (Some s, List.filter (find_equiv s) (!Settings.equivs), lb)
		  else
		    (Some s, eq_list, lb)
	in
	match possible_equivs with
	  [] -> raise (Error("No equivalence corresponds to the one you mention", ext1))
	| [equiv] -> 
	    begin
	      match eq_name_opt with
		None -> 
		  if interactive then
		    begin
		      print_string "Applying ";
		      Display.display_equiv equiv; print_newline();
		      print_string "Please enter variable and/or term mapping for this equivalence: ";
		      let s = read_line() in
		      do_equiv ext1 equiv (s,dummy_ext) state
		    end
		  else
		    do_equiv ext1 equiv ("",dummy_ext) state
	      |	Some _ -> do_equiv ext1 equiv (concat_strings binders, get_ext binders) state
	    end
	| _ -> 
	    if interactive then
	      begin
		let n = ref 0 in
		List.iter (fun equiv -> incr n; print_int (!n); print_string ". "; Display.display_equiv equiv; print_newline()) possible_equivs;
		print_string "Please enter number of equivalence to consider: ";
		let s = read_line() in
		try
		  let equiv = List.nth possible_equivs (int_of_string s - 1) in
		  match eq_name_opt with
		    None -> 
		      print_string "Please enter variable and/or term mapping for this equivalence: ";
		      let s = read_line() in
		      do_equiv ext1 equiv (s,dummy_ext) state
		  | Some _ -> do_equiv ext1 equiv (concat_strings binders, get_ext binders) state
		with Failure _ -> 
		  raise (Error("Incorrect number", dummy_ext))
	      end
	    else
	      raise (Error("Several equivalences correspond to what you mention", ext1))
      end
  | ["quit",_] ->
      raise (End state)
  | ["success",_] ->
      let (state', is_done) = issuccess_with_advise state in
      if is_done then
	begin
	  print_string "===================== Proof starts =======================\n";
	  display_state true state';
	  raise (End state')
	end
      else
	begin
	  print_string "Sorry, the following queries remain unproved:\n";
	  List.iter (fun (a, _, popt) ->
	    if popt == None then
	      begin
		print_string "- ";
		Display.display_query a;
		print_newline()
	      end
	    ) state'.game.current_queries;
	  state'
	end
  | ["show_game",_] ->
      Display.display_process state.game.proc;
      state
  | [("show_game",_);("occ",_)] ->
      Display.display_occurrences := true;
      Display.display_process state.game.proc;
      Display.display_occurrences := false;
      state
  | ["show_state",_] ->
      display_state false state;
      state
  | [("show_facts",_);(occ_s,ext2)] ->
      begin
	try 
	  let occ = int_of_string occ_s in
	  (* First compute the facts, then display them *)
	  Simplify1.improved_def_process None true state.game.proc;
	  Facts.display_facts_at state.game.proc occ;
	  Simplify1.empty_improved_def_process true state.game.proc;
	  state
	with Failure _ ->
	  raise (Error("occurrence " ^ occ_s ^ " should be an integer", ext2))
      end
  | [("out_game",_); (s,_)] ->
      Display.file_out s (fun () -> Display.display_process state.game.proc);
      state
  | [("out_game",_); (s, _); ("occ",_)] ->
      Display.file_out s (fun () ->
	Display.display_occurrences := true;
	Display.display_process state.game.proc;
	Display.display_occurrences := false);
      state
  | [("out_state",_); (s, _)] ->
      Display.file_out s (fun () ->
	display_state false state);
      state
  | [("out_facts",_); (s, _); (occ_s,ext2)] ->
      begin
	try
	  Display.file_out s (fun () ->
	    let occ = int_of_string occ_s in
	    (* First compute the facts, then display them *)
	    Simplify1.improved_def_process None true state.game.proc;
	    Facts.display_facts_at state.game.proc occ;
	    Simplify1.empty_improved_def_process true state.game.proc);
	  state
	with Failure _ ->
	  raise (Error("occurrence " ^ occ_s ^ " should be an integer", ext2))
      end
  | ["auto",_] ->
      begin
	try
	  let (res, state') = execute_any_crypto_rec1 state in
	  match res with
	    CFailure l -> state'
	  | CSuccess state' -> raise (End state')
	with Backtrack ->
	  print_string "Returned to same state after failure of proof with backtracking.\n";
	  state
      end
  | ["set",ext1; s,_; "=",_; v,ext2] ->
      begin
	try
	  let pval =
	    if (String.length v > 0) && ('0' <= v.[0]) && (v.[0] <= '9') then
	      Ptree.I (int_of_string v)
	    else
	      Ptree.S (v, Parsing_helper.dummy_ext)
	  in
	  Settings.do_set s pval
	with
	  Failure _ -> raise (Error("Value " ^ v ^ " is not an integer", ext2))
	| Not_found -> raise (Error("Unknown parameter or value", ext1))
      end;
      state
  | ("allowed_collisions", ext1) :: (((_, ext_s) :: _) as r) ->
      begin
	let coll_s = concat_strings r in
	let lexbuf = Lexing.from_string coll_s in
	try 
	  let coll = 
	    if (!Settings.front_end) == Settings.Channels then 
	      Parser.allowed_coll Lexer.token lexbuf
	    else
	      Oparser.allowed_coll Olexer.token lexbuf
	  in
	  Settings.allowed_collisions := [];
	  Settings.allowed_collisions_collision := [];
	  List.iter (fun (pl,topt) -> 
	    let pl' = List.map (fun (p,exp) -> (map_param p ext_s, exp)) pl in
	    match topt with
	      Some t -> Settings.allowed_collisions := (pl', map_type t ext_s) :: (!Settings.allowed_collisions)
	    | None -> Settings.allowed_collisions_collision :=  pl' :: (!Settings.allowed_collisions_collision)
		  ) coll
	with
	  Parsing.Parse_error -> raise (Error("Syntax error", Parsing_helper.combine_extent ext_s (extent lexbuf)))
	| Error(s,ext) -> raise (Error(s, Parsing_helper.combine_extent ext_s ext))
      end;
      state
  | ["undo",ext] -> undo ext state 1
  | ["undo",_; s,ext1] ->
      begin
	try
	  let v = int_of_string s in
	  undo ext1 state v
	with
	  Failure _ -> 
	    raise (Error("Value " ^ s ^ " should be an integer", ext1))
      end
  | ["restart",_] ->
      let rec restart state =
	match state.prev_state with
	  None -> state
	| Some (_,_,_,state') -> restart state'
      in
      expand_simplify (restart state)
  | ["help",_] | ["?",_] when interactive -> help(); state
  | ["interactive",_] ->
      if interactive then 
	raise (Error("Command interactive not allowed when already in interactive mode", dummy_ext));
      begin
	match interactive_loop state with
	  CSuccess s -> s
	| _ -> Parsing_helper.internal_error "interactive_loop should return CSuccess _"
      end
  | (_,ext1)::l -> 
      if interactive then help();
      raise (Error("Unknown command", ext1))
  | [] -> 
      if interactive then 
	begin
	  help();
	  raise (Error("Unknown command", dummy_ext))
	end
      else
	Parsing_helper.internal_error "Empty command"

and interactive_loop state =
  print_string "Please enter a command: ";
  let s = read_line() in
  let lexbuf = Lexing.from_string s in
  let rec command_from_lexbuf state com_accu lexbuf =
    match Lexer.interactive_command lexbuf with
      Com_elem s -> command_from_lexbuf state (s::com_accu) lexbuf
    | Com_sep ->
	let state' = 
	  if com_accu != [] then
	    interpret_command true state (List.map (fun s -> (s, dummy_ext)) (List.rev com_accu))
	  else
	    state
	in
	command_from_lexbuf state' [] lexbuf
    | Com_end ->
	if com_accu != [] then
	  interpret_command true state (List.map (fun s -> (s, dummy_ext)) (List.rev com_accu))
	else
	  state
  in
  try 
    interactive_loop (command_from_lexbuf state [] lexbuf)
  with End s ->
    CSuccess s
  | Error(mess, extent) ->
      Parsing_helper.display_error mess extent;
      interactive_loop state

let rec execute_proofinfo proof state =
  match proof with
    [] -> 
      print_string "===================== Proof starts =======================\n";
      display_state true state;
      CSuccess state
  | com::rest -> 
      try
	execute_proofinfo rest (interpret_command false state com)
      with End s ->
	CSuccess s
      |	Error(mess, extent) ->
	  Parsing_helper.input_error mess extent

let execute_any_crypto proof state =
  if (!Settings.tex_output) <> "" then
    Displaytex.start();
  let r = 
    match proof with
      Some pr -> execute_proofinfo pr (expand_simplify state)
    | None ->
	if !Settings.interactive_mode then
	  interactive_loop (expand_simplify state)
	else
	  execute_any_crypto state
  in
  if (!Settings.tex_output) <> "" then
    Displaytex.stop();
  r
