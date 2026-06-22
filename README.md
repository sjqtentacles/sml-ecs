# sml-ecs

[![CI](https://github.com/sjqtentacles/sml-ecs/actions/workflows/ci.yml/badge.svg)](https://github.com/sjqtentacles/sml-ecs/actions/workflows/ci.yml)

Entity-Component-System (ECS) architecture with sparse component stores in pure Standard ML

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

(* Create entities *)
val m0 = EntityManager.empty
val (e0, m1) = EntityManager.create m0
val (e1, m2) = EntityManager.create m1

(* Attach components *)
val health = IntStore.set IntStore.empty e0 100
val health = IntStore.set health e1 50
val names  = StringStore.set StringStore.empty e0 "hero"

(* Query components *)
val SOME 100  = IntStore.get health e0
val true      = IntStore.has health e1
val false     = IntStore.has health (snd (EntityManager.create m2))

(* Remove a component *)
val health' = IntStore.remove health e1

(* Destroy an entity — recycles its ID *)
val m3 = EntityManager.destroy m2 e0
val false = EntityManager.isAlive m3 e0

(* Iterate over all living entities *)
val live = EntityManager.alive m2   (* [e0, e1] *)
```

## Example

`make example` builds and runs [`examples/demo.sml`](examples/demo.sml), which
creates entities, attaches `int` and `string` components via two functor
instances, queries and mutates them, and shows that destroyed entity IDs are
recycled:

```
$ make example
Entity manager:
  created entities = [0, 1, 2]
  alive            = [2, 1, 0]

Components:
  health  e0=100 e1=50 e2=30
  name    e0=hero e1=goblin e2=-
  e2 has a name? false

Mutation:
  remove health e1 -> e1 has health? false
  destroy e0 -> isAlive e0 = false
  alive = [2, 1]
  next create reuses id = 0
```

## Testing

```
make test       # MLton
make test-poly  # Poly/ML
make example    # build + run the demo
```

## License

MIT
