# sml-ecs

[![CI](https://github.com/sjqtentacles/sml-ecs/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-ecs/actions/workflows/ci.yml)

Entity-Component-System (ECS) architecture with **generational entity IDs**,
sparse component stores, and multi-component queries in pure Standard ML

## Installation

```
smlpkg add github.com/sjqtentacles/sml-ecs
smlpkg sync
```

## Usage

```sml
(* Instantiate typed component stores with the functor *)
structure IntStore    = MakeComponentStore (struct type t = int    end)
structure StringStore = MakeComponentStore (struct type t = string end)

(* Create entities. An entity is a generational handle {id, gen}. *)
val m0 = EntityManager.empty
val (e0, m1) = EntityManager.create m0
val (e1, m2) = EntityManager.create m1

(* Attach components *)
val health = IntStore.set IntStore.empty e0 100
val health = IntStore.set health e1 50
val names  = StringStore.set StringStore.empty e0 "hero"

(* Query components *)
val SOME 100 = IntStore.get health e0
val true     = IntStore.has health e1

(* Multi-component query/join: entities present in BOTH stores *)
structure Q = MakeQuery2 (structure A = IntStore structure B = StringStore)
val rows = Q.query2 (health, names)              (* (entity * int * string) list *)
val labels = Q.joinWith (fn (h, n) => n ^ ":" ^ Int.toString h) (health, names)

(* Three-store join *)
structure BoolStore = MakeComponentStore (struct type t = bool end)
structure Q3 = MakeQuery3 (structure A = IntStore
                           structure B = StringStore
                           structure C = BoolStore)

(* Destroy an entity — bumps its slot's generation so stale handles die. *)
val m3 = EntityManager.destroy m2 e0
val false = EntityManager.isAlive m3 e0

(* A reused slot gets a fresh generation; the old handle stays invalid. *)
val (e0b, _) = EntityManager.create m3
val true  = (#id e0b = #id e0)        (* same slot *)
val false = (#gen e0b = #gen e0)      (* new generation *)
```

### Destroying an entity (World pattern)

There is no single mutable `World` object; the world is your manager plus your
named stores. To fully remove an entity, destroy it in the manager **and**
`remove` it from each store it might appear in:

```sml
fun destroyEntity (m, hp, names) e =
  ( EntityManager.destroy m e
  , IntStore.remove hp e
  , StringStore.remove names e )
```

Even if you forget to purge a store, **generational IDs prevent stale reads**:
a recreated slot has a new generation, so `get`/`has` with the old handle
return `NONE`/`false` instead of aliasing the new occupant's data.

## API

| Function | Description |
| --- | --- |
| `EntityManager.{empty,create,destroy,isAlive,alive,sameEntity}` | Generational handle allocator. `isAlive` checks id **and** generation. |
| `MakeComponentStore` | Functor producing a typed sparse store keyed by entity slot. |
| `Store.{empty,set,get,remove,has,toList,entities}` | Per-component CRUD; `get`/`has` require an exact id+gen match. |
| `MakeQuery2` / `MakeQuery3` | Functors producing `query2`/`joinWith` / `query3` across stores. |

## Scope and limitations

- **Generational entity IDs** (`{id, gen}`): destroying an entity increments its
  slot generation, so reused slots never alias stale handles. This is a
  deliberate change from a bare `int` id.
- Component stores are **immutable, persistent** sorted association lists:
  `set`/`get`/`remove`/`has` are O(n). Fine for small/medium worlds; not a
  cache-friendly archetype/array backend.
- Queries (`query2`/`query3`/`joinWith`) iterate the first store and probe the
  others, so they are O(nA · cost-of-get); ordering follows the first store.
- The "world" is just a manager + stores you thread yourself; there is no
  global mutable registry and no automatic component purge on destroy (do it
  explicitly — generational guards make a missed purge safe to read, not a leak
  you must rely on).
- Single-threaded; values are immutable so there are no concurrency concerns.

## Example

`make example` builds and runs [`examples/demo.sml`](examples/demo.sml), which
creates entities, attaches `int` and `string` components via two functor
instances, runs a multi-component query, and shows that a reused slot's stale
handle is rejected by the generational guard:

```
$ make example
Entity manager:
  created entities = [e0@g0, e1@g0, e2@g0]
  alive            = [e2@g0, e1@g0, e0@g0]

Components:
  health  e0=100 e1=50 e2=30
  name    e0=hero e1=goblin e2=-
  e2 has a name? false

Query (health AND name):
  e0@g0 hp=100 name=hero
  e1@g0 hp=50 name=goblin

Mutation:
  remove health e1 -> e1 has health? false
  destroy e0 -> isAlive e0 = false
  alive = [e2@g0, e1@g0]
  next create reuses id = e0@g1 (new generation)
  stale handle e0 reads hp? no (generational guard)
```

## Testing

```
make test       # MLton
make test-poly  # Poly/ML
make example    # build + run the demo
```

## License

MIT
