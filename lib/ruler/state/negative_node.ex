defmodule Ruler.State.NegativeNode do
  alias Ruler.{
    Fact,
    State
  }

  @enforce_keys [
    :parent_ref,
    :child_refs,
    :partial_activations,
    :alpha_memory_ref,
    :comparisons,
    :join_results
  ]
  defstruct [
    :parent_ref,
    :child_refs,
    :partial_activations,
    :alpha_memory_ref,
    :comparisons,
    :join_results
  ]

  @type partial_activation :: [Fact.t()]
  @type negative_join_result :: {}
  # it has a join node or negative node for a parent, just like beta memory; or it has the dummy top node as a parent
  @type parent_ref :: State.JoinNode.ref() | State.NegativeNode.ref() | State.BetaMemory.ref()
  # it acts as its own join node, so it has the same kinds of children as join nodes
  @type child_ref :: State.BetaMemory.ref() | State.NegativeNode.ref() | ActivationNode.ref()
  @type t :: %__MODULE__{
          parent_ref: parent_ref | nil,
          child_refs: [child_ref],
          # like a beta memory:
          partial_activations: MapSet.t(partial_activation),
          # and like a join node:
          alpha_memory_ref: State.AlphaMemory.ref(),
          comparisons: [Comparison.t()],
          # plus it keeps track of negative join results:
          join_results: MapSet.t(Fact.t())
        }
  @type ref :: State.RefMap.ref(:negative_node_ref)
end
