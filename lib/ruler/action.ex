defmodule Ruler.Action do
  alias Ruler.{
    Fact
  }

  @type imply :: {:imply, Condition.t()}
  # should reference a 2-arity function that takes an EventContext.t() and an EventContext.activation_event()
  @type effect_handler :: {module(), atom()}
  @type perform_effects :: {:perform_effects, effect_handler}
  @type t :: imply | perform_effects
end
