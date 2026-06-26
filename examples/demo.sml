(* demo.sml - exercise the entity manager (generational IDs), typed component
   stores, and multi-component queries. Deterministic: no RNG, no clock;
   identical output on every run and on both MLton and Poly/ML. *)

structure IntStore    = MakeComponentStore (struct type t = int    end)
structure StringStore = MakeComponentStore (struct type t = string end)

(* Query joining the two stores on entities that have both components *)
structure Q = MakeQuery2 (structure A = IntStore structure B = StringStore)

fun pInt i = Int.toString i
fun pEnt ({id, gen} : EntityManager.entity) =
  "e" ^ pInt id ^ "@g" ^ pInt gen
fun pEntList xs = "[" ^ String.concatWith ", " (List.map pEnt xs) ^ "]"

(* Create three entities *)
val m0 = EntityManager.empty
val (e0, m1) = EntityManager.create m0
val (e1, m2) = EntityManager.create m1
val (e2, m3) = EntityManager.create m2

val () = print "Entity manager:\n"
val () = print ("  created entities = " ^ pEntList [e0, e1, e2] ^ "\n")
val () = print ("  alive            = " ^ pEntList (EntityManager.alive m3) ^ "\n")

(* Attach components *)
val hp = IntStore.set (IntStore.set (IntStore.set IntStore.empty e0 100) e1 50) e2 30
val names = StringStore.set (StringStore.set StringStore.empty e0 "hero") e1 "goblin"

fun showHp e = case IntStore.get hp e of SOME v => pInt v | NONE => "-"
fun showName e = case StringStore.get names e of SOME v => v | NONE => "-"

val () = print "\nComponents:\n"
val () = print ("  health  e0=" ^ showHp e0 ^ " e1=" ^ showHp e1 ^ " e2=" ^ showHp e2 ^ "\n")
val () = print ("  name    e0=" ^ showName e0 ^ " e1=" ^ showName e1 ^ " e2=" ^ showName e2 ^ "\n")
val () = print ("  e2 has a name? " ^ Bool.toString (StringStore.has names e2) ^ "\n")

(* Multi-component query: entities that have BOTH health and a name *)
val () = print "\nQuery (health AND name):\n"
val () = List.app
  (fn (e, h, n) => print ("  " ^ pEnt e ^ " hp=" ^ pInt h ^ " name=" ^ n ^ "\n"))
  (Q.query2 (hp, names))

(* Remove a component, then destroy an entity (its id is recycled with a new gen) *)
val hp' = IntStore.remove hp e1
val () = print "\nMutation:\n"
val () = print ("  remove health e1 -> e1 has health? " ^ Bool.toString (IntStore.has hp' e1) ^ "\n")
val m4 = EntityManager.destroy m3 e0
val () = print ("  destroy e0 -> isAlive e0 = " ^ Bool.toString (EntityManager.isAlive m4 e0) ^ "\n")
val () = print ("  alive = " ^ pEntList (EntityManager.alive m4) ^ "\n")
val (e3, _) = EntityManager.create m4
val () = print ("  next create reuses id = " ^ pEnt e3 ^ " (new generation)\n")
val () = print ("  stale handle e0 reads hp? "
                ^ (case IntStore.get hp e3 of SOME _ => "yes" | NONE => "no (generational guard)") ^ "\n")
