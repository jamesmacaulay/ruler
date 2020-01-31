defmodule Ruler.State.ActivationNode do
  alias Ruler.{
    Activation,
    State
  }

  @enforce_keys [:parent, :rule, :activations]
  defstruct [:parent, :rule, :activations]

  @type t :: %__MODULE__{
          parent: State.JoinNode.ref(),
          rule: Rule.id(),
          activations: MapSet.t(Activation.t())
        }
  @type ref :: {:activation_node_ref, State.RefMap.ref()}
end
