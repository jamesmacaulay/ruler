defmodule Ruler.State.ActivationNode do
  alias Ruler.{
    Activation,
    State
  }

  @enforce_keys [:parent_ref, :rule_id, :activations]
  defstruct [:parent_ref, :rule_id, :activations]

  @type t :: %__MODULE__{
          parent_ref: State.JoinNode.ref(),
          rule_id: Rule.id(),
          activations: MapSet.t(Activation.t())
        }
  @type ref :: {:activation_node_ref, State.RefMap.ref()}
end
