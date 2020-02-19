defmodule Ruler.Activation do
  @enforce_keys [:rule_id, :facts, :bindings]
  defstruct [:rule_id, :facts, :bindings]

  @type t :: %__MODULE__{
          rule_id: Rule.id(),
          facts: [Fact.t()],
          bindings: Condition.bindings_map()
        }
end
