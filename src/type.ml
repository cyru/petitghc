open Ast

(* abstract syntax of the types *)
type typ = Tbool 
         | Tchar 
         | Tinteger
         | TIO
         | Tvar of tvar
         | Tarrow of typ * typ
         | Tlist of typ
and tvar =
    { id : int;
      mutable def : typ option }

let rec print_type = function
    | Tbool -> Printf.printf "Bool"
    | Tchar -> Printf.printf "Char"
    | Tinteger -> Printf.printf "Integer"
    | TIO -> Printf.printf "IO"
    | Tvar _ -> Printf.printf "Tvar"
    | Tarrow (t1,t2) -> Printf.printf "Tarrow "; print_type t1; 
                        Printf.printf " "; print_type t2
    | Tlist t -> Printf.printf "List "; print_type t

(* module that encapsulates types variables and provides a function to 
 * compare them *)
module V = struct
    type t = tvar
    let compare v1 v2 = Pervasives.compare v1.id v2.id
    let equal v1 v2 = v1.id = v2.id
    let create = let r = ref 0 in fun () -> incr r; { id = !r; def = None }
end

(* head : typ -> typ
 * normalizes a type in head: head t returns a type equal to t
 * that isn't of the form Tvar {def = Some _}, i.e head t follows 
 * the definitions of the type variables at the head of t, as long 
 * as there are some. *)
let rec head = function
| Tvar {def = Some t} -> head t
| x                   -> x

(* canon : typ -> typ
 * normalizes a type entirely, i.e applies head in depth *)
let rec canon z = match (head z) with
| Tarrow (x,y)   -> Tarrow (canon x, canon y)
| Tlist x        -> Tlist (canon x)
| x              -> x

exception UnificationFailure of typ * typ

let unification_error t1 t2 = raise (UnificationFailure
    (canon t1, canon t2))

(* occur : tvar -> typ -> bool
 * checks the occurence of a type variable inside a type, we can
 * suppose the variable is undefined *)
let rec occur v t =
    match (head t) with
    | Tarrow (t1,t2) -> occur v t1 || occur v t2
    | Tlist t        -> occur v t
    | Tvar w         -> V.equal v w
    | _              -> false


(* unify : typ -> typ -> unit 
 * does the unification of two types *)
let rec unify t1 t2 =
    match (head t1, head t2) with
    | Tinteger, Tinteger -> ()
    | Tchar, Tchar       -> ()
    | Tbool, Tbool       -> ()
    | TIO, TIO           -> ()
    | Tvar v1, Tvar v2 when V.equal v1 v2 -> ()
    | Tvar v1 as t1,t2 -> 
            if occur v1 t2 then unification_error t1 t2;
            assert (v1.def = None);
            v1.def <- Some t2
    | t1, Tvar v2 -> unify t2 t1
    | Tarrow (t1,t1'), Tarrow(t2,t2') -> unify t1 t2; unify t1' t2'
    | Tlist t1, Tlist t2 -> unify t1 t2 
    | (t1,t2) -> unification_error t1 t2

let cant_unify ty1 ty2 =
    try let _ = unify ty1 ty2 in false with UnificationFailure _ -> true

(* schema de type *)
module Vset = Set.Make(V)

type schema = { vars : Vset.t; typ : typ }

(* free variables *)

let rec fvars t = match head t with
| Tarrow (t1, t2) -> Vset.union (fvars t1) (fvars t2)
| Tvar v  -> Vset.singleton v
| Tlist v -> fvars v
| _       -> Vset.empty

let norm_varset s =
    Vset.fold (fun v s -> Vset.union (fvars (Tvar v)) s) s Vset.empty

(* environnement c'est une table de bindings (string -> schema),
 * et un ensemble de variables de types libres *)

module Smap = Map.Make(String)

type env = { bindings : schema Smap.t; fvars : Vset.t }

let empty = { bindings = Smap.empty; fvars = Vset.empty }


let add gen x t env =
    let vt = fvars t in
    let s, fvars =
        if gen then
            let env_fvars = norm_varset env.fvars in
            { vars = Vset.diff vt env_fvars; typ = t }, env.fvars
        else
            { vars = Vset.empty; typ = t }, Vset.union env.fvars vt
    in
    { bindings = Smap.add x s env.bindings; fvars = fvars }

let base = List.fold_left (fun acc (x,t) -> add false x t acc)
            empty
            ["div"    , Tarrow (Tinteger, Tarrow (Tinteger, Tinteger));
             "rem"    , Tarrow (Tinteger, Tarrow (Tinteger, Tinteger));
             "error"  , Tarrow (Tlist Tchar, Tvar (V.create ()))      ;
             "putChar", Tarrow (Tchar, TIO)
            ] 

module Vmap = Map.Make(V)

(* find x env donne une instance fraîche de env(x) *)
let find x env =
    let tx = Smap.find x env.bindings in
    let s =
        Vset.fold (fun v s -> Vmap.add v (Tvar (V.create ())) s)
            tx.vars Vmap.empty
    in
    let rec subst t = match head t with
    | Tvar x as t -> (try Vmap.find x s with Not_found -> t)
    | Tinteger    -> Tinteger
    | TIO         -> TIO
    | Tchar       -> Tchar
    | Tbool       -> Tbool
    | Tlist t     -> Tlist (subst t)
    | Tarrow (t1, t2) -> Tarrow (subst t1, subst t2)
    in
    subst tx.typ

(* W algorithm *)
let rec w env t = Ast.print_expr t; Printf.printf "\n";
    match t with
    | Simple (e::es,p) -> 
       failwith "there shouldn't be any simple expressions"
    | Single e ->
        ws env e
    | App (_,_) ->
        failwith "app undefined"
    | Lambda (param,body) -> 
        failwith "lambda undefined"
    | Neg (e,_) ->
        unify Tinteger (w env e);
        Tinteger
    | BinOp (e1,o,e2,_) ->
        let t1 = w env e1 and t2 = w env e2 in
        begin match o with
        | Plus | Minus | Time ->
            unify t1 Tinteger; unify t2 Tinteger;
            Tinteger
        | LowerEq | GreaterEq | Greater | Lower | Unequal | Equal ->
            unify t1 Tinteger; unify t2 Tinteger;
            Tbool
        | And | Or ->
            unify t1 Tbool; unify t2 Tbool;
            Tbool
        | Colon ->
            unify (Tlist t1) t2; Tlist t1
        end
    | If (e1,e2,e3,_) ->
        let t1 = w env e1 and t2 = w env e2 and t3 = w env e3 in
        unify t1 Tbool;
        unify t2 t3;
        t1
    | Let (bs, e, _) ->
         failwith "let undefined"
    | Case (e1,e2,x1,x2,e3,_) ->
         Printf.printf "case\n";
         let t1 = w env e1 and t2 = w env e2 in
         let env' = add true x2 t2 (add true x1 t1 env) in
         let t3 = w env' e3 in
         unify t3 t2;
         print_type t1; Printf.printf "\n";
         print_type t2; Printf.printf "\n";
         print_type t3; Printf.printf "\n";
         t2
    | Do (es,_) -> 
         List.iter (fun e -> unify (w env e) TIO) es;
         TIO
    | Return _ -> TIO

and ws env = function (* type of simple expressions *)
    | Par (e,_)        -> w env e
    | Id (x,_)         -> find x env
    | Cst (Int _,_)    -> Tinteger
    | Cst (Char _,_)   -> Tchar
    | Cst (String _,_) -> Tlist Tchar
    | Cst _            -> Tbool
    | List ([],p)      -> failwith "we don't handle empty lists yet"
    | List (ls,p)      -> w env (List.hd ls)

and wd env = function
    | (x,_,e,_) -> w env e


(* on fait un fold sur la liste des definitions avec pour accumulateur l'environnement *)

let infer (f : Ast.file) =
    match f with
    | [d] -> wd base d
    | _   -> failwith "we don't deal with multiple definitions yet"


