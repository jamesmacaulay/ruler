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
    :proposed_activations,
    :committed_activations
  ]
  defstruct [
    :facts,
    :rules,
    :constant_test_nodes,
    :alpha_memories,
    :beta_memories,
    :join_nodes,
    :activation_nodes,
    :proposed_activations,
    :committed_activations
  ]

  @type t :: %__MODULE__{
          facts: %{Fact.t() => State.FactInfo.t()},
          rules: %{Rule.id() => Rule.t()},
          constant_test_nodes:
            State.RefMap.t(:constant_test_node_ref, State.ConstantTestNode.t()),
          alpha_memories: State.RefMap.t(:alpha_memory_ref, State.AlphaMemory.t()),
          beta_memories: State.RefMap.t(:beta_memory_ref, State.BetaMemory.t()),
          join_nodes: State.RefMap.t(:join_node_ref, State.JoinNode.t()),
          activation_nodes: %{State.ActivationNode.ref() => State.ActivationNode.t()},
          proposed_activations: MapSet.t(Activation.t()),
          committed_activations: MapSet.t(Activation.t())
        }

  @type activation_event :: {:activate, Activation.t()} | {:deactivate, Activation.t()}

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
      activation_nodes: %{},
      proposed_activations: MapSet.new(),
      committed_activations: MapSet.new()
    }
  end

  @spec conflict_set(t) :: MapSet.t(activation_event)
  def conflict_set(state) do
    activate_events =
      MapSet.difference(state.proposed_activations, state.committed_activations)
      |> MapSet.new(&{:activate, &1})

    deactivate_events =
      MapSet.difference(state.committed_activations, state.proposed_activations)
      |> MapSet.new(&{:deactivate, &1})

    MapSet.union(activate_events, deactivate_events)
  end
end
