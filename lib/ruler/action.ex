defmodule Ruler.Action do
  alias Ruler.{
    FactTemplate
  }

  @type imply :: {:imply, FactTemplate.t()}
  # should reference a 2-arity function that takes an Engine.t() and a State.activation_event()
  @type effect_handler :: {module(), atom()}
  @type perform_effects :: {:perform_effects, effect_handler}
  @type t :: imply | perform_effects
end
