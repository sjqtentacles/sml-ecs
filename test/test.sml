structure IntStore = MakeComponentStore (struct type t = int end)
structure StringStore = MakeComponentStore (struct type t = string end)
structure BoolStore = MakeComponentStore (struct type t = bool end)

structure Q2 = MakeQuery2 (structure A = IntStore structure B = StringStore)
structure Q3 = MakeQuery3 (structure A = IntStore
                           structure B = StringStore
                           structure C = BoolStore)

structure EcsTests =
struct
  fun run () =
    let
      val m0 = EntityManager.empty
      val (e0, m1) = EntityManager.create m0
      val (e1, m2) = EntityManager.create m1
      val (e2, m3) = EntityManager.create m2
    in
      Harness.section "EntityManager (generational)";
      Harness.check "e0 alive" (EntityManager.isAlive m3 e0);
      Harness.check "e1 alive" (EntityManager.isAlive m3 e1);
      Harness.check "e2 alive" (EntityManager.isAlive m3 e2);
      Harness.checkInt "e0 id is 0" (0, #id e0);
      Harness.checkInt "e0 gen is 0" (0, #gen e0);
      let
        val m4 = EntityManager.destroy m3 e1
      in
        Harness.check "e1 dead after destroy" (not (EntityManager.isAlive m4 e1));
        Harness.check "e0 still alive" (EntityManager.isAlive m4 e0);
        let
          val (e3, m5) = EntityManager.create m4
        in
          Harness.check "reused entity alive" (EntityManager.isAlive m5 e3);
          Harness.checkInt "reused slot id is e1's id" (#id e1, #id e3);
          Harness.check "reused slot has fresh generation" (#gen e3 <> #gen e1);
          (* The stale handle e1 (old gen) must NOT be considered alive even
             though its slot id is reused. *)
          Harness.check "stale handle e1 not alive after reuse"
            (not (EntityManager.isAlive m5 e1));
          ()
        end
      end;

      Harness.section "ComponentStore";
      let
        val cs0 = IntStore.empty
        val cs1 = IntStore.set cs0 e0 42
        val cs2 = IntStore.set cs1 e1 99
      in
        Harness.check "e0 has component" (IntStore.has cs2 e0);
        Harness.check "e1 has component" (IntStore.has cs2 e1);
        Harness.check "e2 has no component" (not (IntStore.has cs2 e2));
        Harness.checkInt "e0 component = 42"
          (42, case IntStore.get cs2 e0 of SOME v => v | NONE => ~1);
        let
          val cs3 = IntStore.remove cs2 e0
        in
          Harness.check "e0 removed" (not (IntStore.has cs3 e0));
          Harness.check "e1 still present" (IntStore.has cs3 e1);
          Harness.checkInt "entity count"
            (1, length (IntStore.entities cs3));
          ()
        end
      end;

      Harness.section "stale handle cannot read newer occupant";
      let
        (* destroy e0, recreate into its slot, set a component on the new
           handle, then try to read with the stale (old-gen) handle *)
        val m4 = EntityManager.destroy m3 e0
        val (e0b, _) = EntityManager.create m4
        val store = IntStore.set IntStore.empty e0b 777
      in
        Harness.check "same slot id" (#id e0b = #id e0);
        Harness.check "fresh handle reads its value" (IntStore.has store e0b);
        Harness.check "stale handle does NOT read new occupant's value"
          (case IntStore.get store e0 of NONE => true | SOME _ => false);
        Harness.check "stale handle has = false" (not (IntStore.has store e0))
      end;

      Harness.section "query2 / joinWith";
      let
        val hp = IntStore.set (IntStore.set (IntStore.set IntStore.empty e0 100) e1 50) e2 30
        val nm = StringStore.set (StringStore.set StringStore.empty e0 "hero") e2 "orc"
        val joined = Q2.query2 (hp, nm)
        val ids = List.map (fn (e, _, _) => #id e) joined
      in
        (* only e0 and e2 have both an int and a string *)
        Harness.checkInt "query2 yields 2 rows" (2, List.length joined);
        Harness.check "query2 includes e0" (List.exists (fn i => i = 0) ids);
        Harness.check "query2 includes e2" (List.exists (fn i => i = 2) ids);
        Harness.check "query2 excludes e1 (no name)"
          (not (List.exists (fn i => i = 1) ids));
        let
          val combined = Q2.joinWith (fn (h, n) => n ^ ":" ^ Int.toString h) (hp, nm)
          val e0row = List.find (fn (e, _) => #id e = 0) combined
        in
          Harness.checkString "joinWith combines components"
            ("hero:100", case e0row of SOME (_, s) => s | NONE => "")
        end
      end;

      Harness.section "query3";
      let
        val hp = IntStore.set (IntStore.set IntStore.empty e0 100) e1 50
        val nm = StringStore.set (StringStore.set StringStore.empty e0 "hero") e1 "goblin"
        val act = BoolStore.set BoolStore.empty e0 true  (* only e0 has all three *)
        val joined = Q3.query3 (hp, nm, act)
      in
        Harness.checkInt "query3 yields 1 row" (1, List.length joined);
        Harness.check "query3 row is e0"
          (case joined of [(e, _, _, _)] => #id e = 0 | _ => false)
      end;

      Harness.section "destroyEntity purges all stores (World pattern)";
      let
        (* The documented World pattern: destroy in the manager AND remove from
           every component store the entity could be in. *)
        val hp = IntStore.set (IntStore.set IntStore.empty e0 100) e1 50
        val nm = StringStore.set (StringStore.set StringStore.empty e0 "hero") e1 "goblin"
        (* purge e1 from both stores + manager *)
        val m4 = EntityManager.destroy m3 e1
        val hp' = IntStore.remove hp e1
        val nm' = StringStore.remove nm e1
      in
        Harness.check "e1 gone from manager" (not (EntityManager.isAlive m4 e1));
        Harness.check "e1 gone from int store" (not (IntStore.has hp' e1));
        Harness.check "e1 gone from string store" (not (StringStore.has nm' e1));
        Harness.check "e0 untouched in int store" (IntStore.has hp' e0);
        Harness.check "e0 untouched in string store" (StringStore.has nm' e0)
      end;
      ()
    end
end
