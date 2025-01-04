open Core
open Ast.IR

exception TypeError of string
(* exception Unimplemented *)

let (=) = Stdlib.(=)

(* Checks that a type is legal. *)
let rec typecheck_type (tenv : String.Set.t) (tau : Type.t) : Type.t =
  match tau with
   | Type.Var x ->
     if Set.mem tenv x then tau
     else raise (TypeError (Printf.sprintf "Unbound type variable %s" x))
   | Type.Product (t1, t2) -> Type.Product (typecheck_type tenv t1, typecheck_type tenv t2)
   | Type.Sum (t1, t2) -> Type.Sum (typecheck_type tenv t1, typecheck_type tenv t2)
   | Type.Fn (t1, t2) -> Type.Fn (typecheck_type tenv t1, typecheck_type tenv t2)
   | Type.ForAll(s, t1) -> Type.ForAll(s, typecheck_type (Set.add tenv s) t1)
   | Type.Exists(s, t1) -> Type.Exists(s, typecheck_type (Set.add tenv s) t1)
   | Type.Int -> tau

(* You need to implement the statics for the remaining cases below.
 * We have provided you with implementations of the other cases that you may
 * refer to.
 *
 * Note that you'll have to use OCaml sets to do this assignment. The semantics
 * for sets will be similar to maps. Like Maps, Sets are also immutable, so
 * any result from a set function will be different from the source. You may
 * find the functions Set.add and Set.find to be useful, in addition to others.
 *)
let rec typecheck_term (tenv : String.Set.t) (env : Type.t String.Map.t) (t : Term.t) : Type.t =
  match t with
  | Term.Int _ -> Type.Int

  | Term.Var x -> (
      match (Map.find env x) with
      | Some _type -> (typecheck_type tenv _type) 
      | None -> raise (TypeError "Does not typecheck 01")
    )

  | Term.Lam (x, arg_tau, body) -> (
      let arg_tau_type = typecheck_type tenv arg_tau in
      let new_map = Map.set env ~key:x ~data:arg_tau_type in
      Type.Fn(arg_tau_type, typecheck_term tenv new_map body)
    )

  | Term.App (fn, arg) -> (
      let tau1 = typecheck_term tenv env fn in
      let tau2 = typecheck_term tenv env arg in
      match (tau1, tau2) with
      | (Type.Fn (type_a, type_b), type_c) -> (
          if Type.aequiv type_a type_c then type_b
          else raise (TypeError "Does not typecheck 03")
        )
      | _ -> raise (TypeError "Does not typecheck 05")
    )

  | Term.Binop (_, t1, t2) ->
      let tau1 = typecheck_term tenv env t1 in
      let tau2 = typecheck_term tenv env t2 in
          if Type.aequiv tau1 tau2 then tau1
          else raise (TypeError "Does not typecheck binop")
          

  | Term.Tuple (t1, t2) ->
      let tau1 = typecheck_term tenv env t1 in
      let tau2 = typecheck_term tenv env t2 in
      Type.Product(tau1, tau2)

  | Term.Project (t, dir) -> (
      let tau = typecheck_term tenv env t in
      match tau with
        | Type.Product(tau1, tau2) -> (
          match dir with
          | Ast.Left -> tau1
          | Ast.Right -> tau2
        )
        | _ -> raise (TypeError "Does not typecheck project")
  )

  | Term.Inject (arg, dir, sum_tau) -> (
    let sum_type = typecheck_type tenv sum_tau in
    match sum_type with
      | Type.Sum(tau1, tau2) ->
        (
          let tau = typecheck_term tenv env arg in
          match dir with
          | Ast.Left ->
            if Type.aequiv tau tau1 then sum_type
            else raise (TypeError "Does not typecheck inject-L")
          | Ast.Right ->
            if Type.aequiv tau tau2 then sum_type
            else raise (TypeError "Does not typecheck inject-R")
        )
      | _ -> raise (TypeError "Does not typecheck inject sum_tau")
  )

  | Term.Case (switch, (x1, t1), (x2, t2)) -> (
    let tau = typecheck_term tenv env switch in
    match tau with 
      | Type.Sum(tau1, tau2) ->
        let new_env_x1 = Map.set env ~key:x1 ~data:tau1 in
        let t1_type = typecheck_term tenv new_env_x1 t1 in
        let new_env_x2 = Map.set env ~key:x2 ~data:tau2 in
        let t2_type = typecheck_term tenv new_env_x2 t2 in
        if Type.aequiv t1_type t2_type then
          t1_type
        else
          raise (TypeError "Does not typecheck case")
      | _ -> raise (TypeError "Does not typecheck case")
    )


  | Term.TLam (x, t) -> (
      let new_tenv = Set.add tenv x in
      let tau = typecheck_term new_tenv env t in
      Type.ForAll(x, tau)
  )


  | Term.TApp (t, arg_tau) -> (
      let tau2 = typecheck_type tenv arg_tau in
      let t_type = typecheck_term tenv env t in
      match t_type with
        | Type.ForAll(x, tau1) -> Type.substitute x tau2 tau1
        | _ -> raise (TypeError "Does not typecheck TApp")
  )

  | Term.TPack (abstracted_tau, t, existential_type) -> (
      let tau1 = typecheck_type tenv abstracted_tau in
      let exist_type = typecheck_type tenv existential_type in
      match exist_type with
        | Type.Exists(x, tau2) -> (
          if Type.aequiv (Type.substitute x tau1 tau2) (typecheck_term tenv env t) then
            Type.Exists(x, tau2)
          else
            raise (TypeError "Does not typecheck TPack")
        )
        | _ -> raise (TypeError "Does not typecheck TPack")
  )

  | Term.TUnpack (xty, xterm, arg, body) -> (
      let t1_type = typecheck_term tenv env arg in
      match t1_type with
        | Type.Exists(xty1, tau1) -> (
            if xty1 = xty then
              let new_tenv = Set.add tenv xty in
              let new_env = Map.set env ~key:xterm ~data:tau1 in
              let tau2 = typecheck_term new_tenv new_env body in
              tau2
            else
              raise (TypeError "Does not typecheck TUnpack")
        )
        | _ -> raise (TypeError "Does not typecheck TUnpack")
  )

let typecheck t =
  try Ok (typecheck_term String.Set.empty String.Map.empty t)
  with TypeError s -> Error s

let inline_tests () =
  (* Typechecks Pack and Unpack*)
  let exist =
    Type.Exists("Y", Type.Int)
  in
  let pack =
    Term.TPack(Type.Int, Term.Int 5, exist)
  in
  let unpack =
    Term.TUnpack("Y", "y", pack, Term.Var "y")
  in
  assert(typecheck unpack = Ok(Type.Int));

  (* Typecheck Inject *)
  let inj =
    Term.Inject(Term.Int 5, Ast.Left, Type.Sum(Type.Int, Type.Int))
  in
  assert (typecheck inj = Ok(Type.Sum(Type.Int, Type.Int)));

  (* Typechecks Tuple *)
  let tuple =
    Term.Tuple(((Int 3), (Int 4)))
  in
  assert (typecheck tuple = Ok(Type.Product(Type.Int, Type.Int)));

  (* Typechecks Case *)
  let inj =
    Term.Inject(Term.Int 5, Ast.Left, Type.Sum(Type.Int, Type.Product(Type.Int, Type.Int)))
  in
  let case1 = ("case1", Term.Int 8)
  in
  let case2 = ("case2", Term.Int 0)
  in
  let switch = Term.Case(inj, case1, case2)
  in
  assert (typecheck switch = Ok(Type.Int));

  (* Inline Tests from Assignment 3 *)
  let t1 = Term.Lam ("x", Type.Int, Term.Var "x") in
  assert (typecheck t1 = Ok(Type.Fn(Type.Int, Type.Int)));

  let t2 = Term.Lam ("x", Type.Int, Term.Var "y") in
  assert (Result.is_error (typecheck t2));

  let t3 = Term.App (t1, Term.Int 3) in
  assert (typecheck t3 = Ok(Type.Int));

  let t4 = Term.App (t3, Term.Int 3) in
  assert (Result.is_error (typecheck t4));

  let t5 = Term.Binop (Ast.Add, Term.Int 0, t1) in
  assert (Result.is_error (typecheck t5))

let () = inline_tests ()
