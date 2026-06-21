structure EntityManager : ENTITY_MANAGER =
struct
  type entity = int
  type manager = {next: int, free: int list, alive: int list}

  val empty = {next=0, free=[], alive=[]}

  fun create {next, free, alive} =
    case free of
      (e :: rest) => (e, {next=next, free=rest, alive=e :: alive})
    | []          => (next, {next=next+1, free=[], alive=next :: alive})

  fun destroy {next, free, alive} eid =
    {next=next, free=eid :: free,
     alive=List.filter (fn e => e <> eid) alive}

  fun isAlive {next=_, free=_, alive} eid =
    List.exists (fn e => e = eid) alive

  fun alive (m : manager) = #alive m
end

functor MakeComponentStore (C : sig type t end) :>
  COMPONENT_STORE where type component = C.t =
struct
  type entity = int
  type component = C.t
  type store = (entity * component) list

  val empty = []

  fun set store eid comp =
    let fun upd [] = [(eid, comp)]
          | upd ((e, c) :: rest) =
              if e = eid then (eid, comp) :: rest
              else if e < eid then (e, c) :: upd rest
              else (eid, comp) :: (e, c) :: rest
    in upd store end

  fun get store eid =
    case List.find (fn (e, _) => e = eid) store of
      NONE        => NONE
    | SOME (_, c) => SOME c

  fun remove store eid =
    List.filter (fn (e, _) => e <> eid) store

  fun has store eid =
    List.exists (fn (e, _) => e = eid) store

  fun toList store = store

  fun entities store = List.map (fn (e, _) => e) store
end
