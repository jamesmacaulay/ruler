defmodule Ruler.State.ActivationNode do
  alias Ruler.{
    Condition,
    State
  }

  @enforce_keys [:parent_ref, :rule_id, :conditions]
  defstruct [:parent_ref, :rule_id, :conditions]

  @type t :: %__MODULE__{
          parent_ref: State.JoinNode.ref(),
          rule_id: Rule.id(),
          conditions: [Condition.t()]
        }
  @type ref :: {:activation_node_ref, State.RefMap.ref()}
end
