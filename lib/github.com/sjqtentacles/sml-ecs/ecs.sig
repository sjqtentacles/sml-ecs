(* Generational entity IDs: an entity is a slot `id` plus a `gen`eration
   counter. Destroying an entity bumps its slot's generation, so a stale handle
   (old gen) compares unequal to the new occupant and cannot read its data. *)

signature ENTITY_MANAGER =
sig
  type entity = {id: int, gen: int}
  type manager

  val empty   : manager
  val create  : manager -> entity * manager
  val destroy : manager -> entity -> manager
  val isAlive : manager -> entity -> bool   (* alive AND generation matches *)
  val alive   : manager -> entity list

  (* equality on full handles (id and generation) *)
  val sameEntity : entity * entity -> bool
end

signature COMPONENT_STORE =
sig
  type entity = {id: int, gen: int}
  type component
  type store

  val empty    : store
  val set      : store -> entity -> component -> store
  val get      : store -> entity -> component option   (* exact id+gen match *)
  val remove   : store -> entity -> store
  val has      : store -> entity -> bool
  val toList   : store -> (entity * component) list
  val entities : store -> entity list
end

(* Multi-component query / join over two component stores. Instantiate with two
   COMPONENT_STORE structures sharing the entity type. *)
signature QUERY2 =
sig
  type entity = {id: int, gen: int}
  type storeA
  type storeB
  type compA
  type compB

  (* entities present in BOTH stores, with both components *)
  val query2   : storeA * storeB -> (entity * compA * compB) list
  (* generalized: combine matched components with `f` *)
  val joinWith : (compA * compB -> 'c) -> storeA * storeB -> (entity * 'c) list
end

signature QUERY3 =
sig
  type entity = {id: int, gen: int}
  type storeA
  type storeB
  type storeC
  type compA
  type compB
  type compC

  val query3 : storeA * storeB * storeC
               -> (entity * compA * compB * compC) list
end
