defmodule Ruler.State.NegativeNode do
  alias Ruler.{
    State
  }

  @enforce_keys [
    :parent_ref,
    :child_refs,
    :partial_activation_result_counts,
    :alpha_memory_ref,
    :comparisons,
    :join_result_counts
  ]
  defstruct [
    :parent_ref,
    :child_refs,
    :partial_activation_result_counts,
    :alpha_memory_ref,
    :comparisons,
    :join_result_counts
  ]

  @type partial_activation :: State.BetaMemory.partial_activation()
  @type negative_join_result :: {}
  # it has a join node or negative node for a parent, just like beta memory; or it has the dummy top node as a parent
  @type parent_ref :: State.JoinNode.ref() | State.NegativeNode.ref() | State.BetaMemory.ref()
  # it acts as its own join node, so it has the same kinds of children as join nodes
  @type child_ref :: State.BetaMemory.ref() | State.NegativeNode.ref() | ActivationNode.ref()
  @type t :: %__MODULE__{
          parent_ref: parent_ref | nil,
          child_refs: [child_ref],
          # like a beta memory, but with counts of negative join results:
          partial_activation_result_counts: Map.t(partial_activation, integer),
          # and like a join node:
          alpha_memory_ref: State.AlphaMemory.ref(),
          comparisons: [Comparison.t()]
        }
  @type ref :: State.RefMap.ref(:negative_node_ref)
end
