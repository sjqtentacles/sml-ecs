structure EntityManager : ENTITY_MANAGER =
struct
  type entity = {id: int, gen: int}

  (* `gens` maps each ever-allocated slot id to its current generation. `alive`
     holds the live ids; `free` holds reusable slot ids. A handle is alive iff
     its id is in `alive` AND its gen equals the slot's current generation. *)
  type manager = {next: int, free: int list, alive: int list, gens: (int * int) list}

  val empty = {next=0, free=[], alive=[], gens=[]}

  fun genOf gens id =
    case List.find (fn (i, _) => i = id) gens of
        SOME (_, g) => g
      | NONE => 0

  fun setGen gens id g =
    (id, g) :: List.filter (fn (i, _) => i <> id) gens

  fun create {next, free, alive, gens} =
    case free of
        (id :: rest) =>
          let val g = genOf gens id
          in ({id=id, gen=g}, {next=next, free=rest, alive=id :: alive, gens=gens}) end
      | [] =>
          ({id=next, gen=0},
           {next=next+1, free=[], alive=next :: alive, gens=setGen gens next 0})

  (* destroy bumps the slot's generation so the freed id, when reused, hands out
     a fresh generation; old handles to the slot become stale. *)
  fun destroy {next, free, alive, gens} ({id, gen}) =
    if List.exists (fn e => e = id) alive andalso genOf gens id = gen
    then {next=next, free=id :: free,
          alive=List.filter (fn e => e <> id) alive,
          gens=setGen gens id (gen + 1)}
    else {next=next, free=free, alive=alive, gens=gens}

  fun isAlive {next=_, free=_, alive, gens} ({id, gen}) =
    List.exists (fn e => e = id) alive andalso genOf gens id = gen

  fun alive (m : manager) =
    List.map (fn id => {id=id, gen=genOf (#gens m) id}) (#alive m)

  fun sameEntity (a : entity, b : entity) = #id a = #id b andalso #gen a = #gen b
end

functor MakeComponentStore (C : sig type t end) :>
  COMPONENT_STORE where type component = C.t =
struct
  type entity = {id: int, gen: int}
  type component = C.t
  (* keyed by slot id, ordered ascending; carries the generation so a stale
     handle (wrong gen) cannot read a newer occupant's component *)
  type store = (entity * component) list

  val empty = []

  fun set store (eid as {id, ...} : entity) comp =
    let fun upd [] = [(eid, comp)]
          | upd ((e : entity, c) :: rest) =
              if #id e = id then (eid, comp) :: rest
              else if #id e < id then (e, c) :: upd rest
              else (eid, comp) :: (e, c) :: rest
    in upd store end

  fun get store ({id, gen} : entity) =
    case List.find (fn (e : entity, _) => #id e = id) store of
        SOME (e, c) => if #gen e = gen then SOME c else NONE
      | NONE => NONE

  fun remove store ({id, ...} : entity) =
    List.filter (fn (e : entity, _) => #id e <> id) store

  fun has store ({id, gen} : entity) =
    List.exists (fn (e : entity, _) => #id e = id andalso #gen e = gen) store

  fun toList store = store

  fun entities store = List.map (fn (e, _) => e) store
end

functor MakeQuery2 (structure A : COMPONENT_STORE
                    structure B : COMPONENT_STORE) :>
  QUERY2 where type storeA = A.store
           and type storeB = B.store
           and type compA = A.component
           and type compB = B.component =
struct
  type entity = {id: int, gen: int}
  type storeA = A.store
  type storeB = B.store
  type compA = A.component
  type compB = B.component

  fun joinWith f (sa, sb) =
    List.foldr
      (fn ((e, ca), acc) =>
         case B.get sb e of
             SOME cb => (e, f (ca, cb)) :: acc
           | NONE => acc)
      [] (A.toList sa)

  fun query2 (sa, sb) =
    List.map (fn (e, (ca, cb)) => (e, ca, cb))
      (joinWith (fn (ca, cb) => (ca, cb)) (sa, sb))
end

functor MakeQuery3 (structure A : COMPONENT_STORE
                    structure B : COMPONENT_STORE
                    structure C : COMPONENT_STORE) :>
  QUERY3 where type storeA = A.store
           and type storeB = B.store
           and type storeC = C.store
           and type compA = A.component
           and type compB = B.component
           and type compC = C.component =
struct
  type entity = {id: int, gen: int}
  type storeA = A.store
  type storeB = B.store
  type storeC = C.store
  type compA = A.component
  type compB = B.component
  type compC = C.component

  fun query3 (sa, sb, sc) =
    List.foldr
      (fn ((e, ca), acc) =>
         case (B.get sb e, C.get sc e) of
             (SOME cb, SOME cc) => (e, ca, cb, cc) :: acc
           | _ => acc)
      [] (A.toList sa)
end
