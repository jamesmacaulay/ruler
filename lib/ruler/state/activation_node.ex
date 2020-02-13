defmodule Ruler.State.ActivationNode do
  alias Ruler.{
    Activation,
    State
  }

  @enforce_keys [:parent, :rule_id, :activations]
  defstruct [:parent, :rule_id, :activations]

  @type t :: %__MODULE__{
          parent: State.JoinNode.ref(),
          rule_id: Rule.id(),
          activations: MapSet.t(Activation.t())
        }
  @type ref :: {:activation_node_ref, State.RefMap.ref()}
end
