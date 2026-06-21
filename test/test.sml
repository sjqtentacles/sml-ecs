structure IntStore = MakeComponentStore (struct type t = int end)
structure StringStore = MakeComponentStore (struct type t = string end)

structure EcsTests =
struct
  fun run () =
    let
      val m0 = EntityManager.empty
      val (e0, m1) = EntityManager.create m0
      val (e1, m2) = EntityManager.create m1
      val (e2, m3) = EntityManager.create m2
    in
      Harness.section "EntityManager";
      Harness.check "e0 alive" (EntityManager.isAlive m3 e0);
      Harness.check "e1 alive" (EntityManager.isAlive m3 e1);
      Harness.check "e2 alive" (EntityManager.isAlive m3 e2);
      let
        val m4 = EntityManager.destroy m3 e1
      in
        Harness.check "e1 dead after destroy" (not (EntityManager.isAlive m4 e1));
        Harness.check "e0 still alive" (EntityManager.isAlive m4 e0);
        let
          val (e3, m5) = EntityManager.create m4
        in
          Harness.check "reused entity alive" (EntityManager.isAlive m5 e3);
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
      Harness.section "String ComponentStore";
      let
        val ss0 = StringStore.empty
        val ss1 = StringStore.set ss0 0 "hero"
        val ss2 = StringStore.set ss1 1 "enemy"
      in
        Harness.checkString "entity 0 name"
          ("hero", case StringStore.get ss2 0 of SOME s => s | NONE => "");
        Harness.checkInt "string store count"
          (2, length (StringStore.toList ss2));
        ()
      end;
      ()
    end
end
