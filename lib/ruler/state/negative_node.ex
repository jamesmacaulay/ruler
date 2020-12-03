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
  @type t :: %__MODULE__{
          parent_ref: parent_ref | nil,
          child_refs: MapSet.t(State.JoinNode.ref()),
          # like a beta memory:
          partial_activations: MapSet.t(partial_activation),
          # and like a join node:
          alpha_memory_ref: State.AlphaMemory.ref(),
          comparisons: [Comparison.t()],
          # plus it keeps track of negative join results:
          join_results: MapSet.t(Fact.t())
        }
  @type ref :: {:negative_node_ref, State.RefMap.ref()}
  # it has a join node for a parent, just like beta memory
  @type parent_ref :: State.JoinNode.ref()
  # it acts as its own join node, so it has the same kinds of children as join nodes
  @type child_ref :: State.JoinNode.child_ref()
end
