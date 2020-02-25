defmodule Ruler.State do
  alias Ruler.{
    Fact,
    Rule,
    State
  }

  @enforce_keys [
    :facts,
    :rules,
    :constant_test_nodes,
    :alpha_memories,
    :beta_memories,
    :join_nodes,
    :activation_nodes
  ]
  defstruct [
    :facts,
    :rules,
    :constant_test_nodes,
    :alpha_memories,
    :beta_memories,
    :join_nodes,
    :activation_nodes
  ]

  @type t :: %__MODULE__{
          facts: %{Fact.t() => State.FactInfo.t()},
          rules: %{Rule.id() => Rule.t()},
          constant_test_nodes:
            State.RefMap.t(:constant_test_node_ref, State.ConstantTestNode.t()),
          alpha_memories: State.RefMap.t(:alpha_memory_ref, State.AlphaMemory.t()),
          beta_memories: State.RefMap.t(:beta_memory_ref, State.BetaMemory.t()),
          join_nodes: State.RefMap.t(:join_node_ref, State.JoinNode.t()),
          activation_nodes: %{State.ActivationNode.ref() => State.ActivationNode.t()}
        }

  @spec new :: State.t()
  def new do
    %State{
      facts: %{},
      rules: %{},
      constant_test_nodes:
        State.RefMap.new(
          :constant_test_node_ref,
          %State.ConstantTestNode{
            field_index: nil,
            target_value: nil,
            alpha_memory_ref: nil,
            child_refs: []
          }
        ),
      alpha_memories: State.RefMap.new(:alpha_memory_ref),
      beta_memories:
        State.RefMap.new(
          :beta_memory_ref,
          %State.BetaMemory{
            parent_ref: nil,
            child_refs: MapSet.new(),
            partial_activations: MapSet.new([[]])
          }
        ),
      join_nodes: State.RefMap.new(:join_node_ref),
      activation_nodes: %{}
    }
  end
end
