defmodule Ruler.State.ActivationNode do
  alias Ruler.{
    Condition,
    State
  }

  @enforce_keys [:parent_ref, :rule_id, :conditions]
  defstruct [:parent_ref, :rule_id, :conditions]

  @type parent_ref :: State.JoinNode.ref() | State.NegativeNode.ref()
  @type t :: %__MODULE__{
          parent_ref: parent_ref,
          rule_id: Rule.id(),
          conditions: [Condition.t()]
        }
  @type ref :: State.RefMap.ref(:activation_node_ref)
end
