defmodule Ruler.Engine.ActivationNode do
  alias Ruler.{
    Activation,
    Condition,
    Engine,
    Fact,
    Rule,
    State
  }

  @type state :: State.t()
  @type node_data :: State.ActivationNode.t()
  @type ref :: State.ActivationNode.ref()
  @type partial_activation :: State.BetaMemory.partial_activation()
  @type rule :: Rule.t()

  @spec fetch!(state, ref) :: node_data
  def fetch!(state, ref) do
    Map.fetch!(state.activation_nodes, ref)
  end

  @spec build(state, rule) :: {state, ref}
  def build(state, rule) do
    {state, parent_ref} =
      Engine.JoinNode.build_or_share_lineage_for_conditions(state, rule.conditions)

    {state, ref} =
      insert(state, %State.ActivationNode{
        parent_ref: parent_ref,
        rule_id: rule.id,
        activations: MapSet.new()
      })

    state =
      state
      |> Engine.JoinNode.add_child_ref!(parent_ref, ref)
      |> update_new_node_with_matches_from_above(ref)

    {state, ref}
  end

  @spec left_activate(state, ref, partial_activation, Fact.t(), :add | :remove) :: state
  def left_activate(state, ref, partial_activation, fact, op) do
    rule_id = State.ActivationNode.rule_id_from_ref(ref)
    facts = Enum.reverse([fact | partial_activation])
    rule = Map.fetch!(state.rules, rule_id)

    add_or_remove_activation(
      state,
      ref,
      %Activation{
        rule_id: rule_id,
        facts: facts,
        bindings: generate_bindings(facts, rule.conditions)
      },
      op
    )
  end

  @spec insert(state, node_data) :: {state, ref}
  defp insert(state, node_data) do
    ref = State.ActivationNode.ref_from_rule_id(node_data.rule_id)
    nodes = Map.put(state.activation_nodes, ref, node_data)

    {%{state | activation_nodes: nodes}, ref}
  end

  @spec update!(state, ref, (node_data -> node_data)) :: state
  defp update!(state, ref, f) do
    nodes = Map.update!(state.activation_nodes, ref, f)
    %{state | activation_nodes: nodes}
  end

  @spec update_new_node_with_matches_from_above(state, ref) :: state
  defp update_new_node_with_matches_from_above(state, ref) do
    parent_ref = fetch!(state, ref).parent_ref
    Engine.JoinNode.update_new_child_node_with_matches_from_above(state, parent_ref, ref)
  end

  @spec generate_bindings([Fact.t()], [Condition.t()]) :: Activation.bindings_map()
  defp generate_bindings(facts, conditions) do
    Enum.zip(facts, conditions)
    |> Enum.reduce(%{}, fn {fact, condition}, bindings ->
      Map.merge(bindings, Condition.bindings(condition, fact))
    end)
  end

  @spec add_or_remove_activation(state, ref, Activation.t(), :add | :remove) :: state
  defp add_or_remove_activation(state, ref, activation, :add) do
    %{
      state
      | latest_activation_events: [
          {:add_activation, activation} | state.latest_activation_events
        ]
    }
    |> update!(ref, fn node ->
      %{
        node
        | activations: MapSet.put(node.activations, activation)
      }
    end)
  end

  defp add_or_remove_activation(state, ref, activation, :remove) do
    %{
      state
      | latest_activation_events: [
          {:remove_activation, activation} | state.latest_activation_events
        ]
    }
    |> update!(ref, fn node ->
      %{
        node
        | activations: MapSet.delete(node.activations, activation)
      }
    end)
  end
end
