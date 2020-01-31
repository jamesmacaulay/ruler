defmodule Ruler.State do
  alias Ruler.{
    Activation,
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
    :activation_nodes,
    :alpha_top_node,
    :beta_top_node,
    :latest_activation_events
  ]
  defstruct [
    :facts,
    :rules,
    :constant_test_nodes,
    :alpha_memories,
    :beta_memories,
    :join_nodes,
    :activation_nodes,
    :alpha_top_node,
    :beta_top_node,
    :latest_activation_events
  ]

  @type t :: %__MODULE__{
          facts: %{Fact.t() => State.FactInfo.t()},
          rules: %{Rule.id() => Rule.t()},
          constant_test_nodes:
            State.RefMap.t(:constant_test_node_ref, State.ConstantTestNode.t()),
          alpha_memories: State.RefMap.t(:alpha_memory_ref, State.AlphaMemory.t()),
          beta_memories: State.RefMap.t(:beta_memory_ref, State.BetaMemory.t()),
          join_nodes: State.RefMap.t(:join_node_ref, State.JoinNode.t()),
          activation_nodes: State.RefMap.t(:activation_node_ref, State.ActivationNode.t()),
          alpha_top_node: State.ConstantTestNode.ref(),
          beta_top_node: State.BetaMemory.ref(),
          latest_activation_events: [Activation.activation_event()]
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
            field: nil,
            target_value: nil,
            alpha_memory: nil,
            children: []
          }
        ),
      alpha_memories: State.RefMap.new(:alpha_memory_ref),
      beta_memories:
        State.RefMap.new(
          :beta_memory_ref,
          %State.BetaMemory{
            parent: nil,
            children: MapSet.new(),
            partial_activations: MapSet.new([[]])
          }
        ),
      join_nodes: State.RefMap.new(:join_node_ref),
      activation_nodes: State.RefMap.new(:activation_node_ref),
      alpha_top_node: {:constant_test_node_ref, 0},
      beta_top_node: {:beta_memory_ref, 0},
      latest_activation_events: []
    }
  end
end
