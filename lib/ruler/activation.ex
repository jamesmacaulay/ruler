defmodule Ruler.Activation do
  @enforce_keys [:rule_id, :conditions, :facts, :bindings]
  defstruct [:rule_id, :conditions, :facts, :bindings]

  @type t :: %__MODULE__{
          rule_id: Rule.id(),
          conditions: [Condition.t()],
          facts: [Fact.t()],
          bindings: FactTemplate.bindings_map()
        }
end
