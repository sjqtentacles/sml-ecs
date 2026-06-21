signature ENTITY_MANAGER =
sig
  type entity = int
  type manager

  val empty   : manager
  val create  : manager -> entity * manager
  val destroy : manager -> entity -> manager
  val isAlive : manager -> entity -> bool
  val alive   : manager -> entity list
end

signature COMPONENT_STORE =
sig
  type entity = int
  type component
  type store

  val empty    : store
  val set      : store -> entity -> component -> store
  val get      : store -> entity -> component option
  val remove   : store -> entity -> store
  val has      : store -> entity -> bool
  val toList   : store -> (entity * component) list
  val entities : store -> entity list
end
