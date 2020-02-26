defmodule Ruler.Engine.ActivationNode do
  alias Ruler.{
    Activation,
    FactTemplate,
    Engine,
    Fact,
    Rule,
    State
  }

  @type state :: State.t()
  @type engine :: Engine.t()
  @type node_data :: State.ActivationNode.t()
  @type ref :: State.ActivationNode.ref()
  @type partial_activation :: State.BetaMemory.partial_activation()
  @type rule :: Rule.t()

  @spec fetch!(state, ref) :: node_data
  def fetch!(state, ref) do
    Map.fetch!(state.activation_nodes, ref)
  end

  @spec fetch_with_rule_id!(state, Rule.id()) :: node_data
  def fetch_with_rule_id!(state, rule_id) do
    fetch!(state, State.ActivationNode.ref_from_rule_id(rule_id))
  end

  @spec build(engine, rule) :: engine
  def build(engine, rule) do
    {engine, parent_ref} =
      Engine.JoinNode.build_or_share_lineage_for_conditions(engine, rule.conditions)

    {engine, ref} =
      insert(engine, %State.ActivationNode{
        parent_ref: parent_ref,
        rule_id: rule.id
      })

    engine
    |> Engine.JoinNode.add_child_ref!(parent_ref, ref)
    |> update_new_node_with_matches_from_above(ref)
  end

  @spec left_activate(engine, ref, partial_activation, Fact.t(), :add | :remove) :: engine
  def left_activate(engine, ref, partial_activation, fact, op) do
    rule_id = State.ActivationNode.rule_id_from_ref(ref)
    facts = Enum.reverse([fact | partial_activation])
    rule = Map.fetch!(engine.state.rules, rule_id)

    add_or_remove_activation(
      engine,
      %Activation{
        rule_id: rule_id,
        facts: facts,
        bindings: generate_bindings(facts, rule.conditions)
      },
      op
    )
  end

  @spec insert(engine, node_data) :: {engine, ref}
  defp insert(engine, node_data) do
    state = engine.state
    ref = State.ActivationNode.ref_from_rule_id(node_data.rule_id)
    nodes = Map.put(state.activation_nodes, ref, node_data)
    state = %{state | activation_nodes: nodes}
    {%{engine | state: state}, ref}
  end

  @spec update_new_node_with_matches_from_above(engine, ref) :: engine
  defp update_new_node_with_matches_from_above(engine, ref) do
    parent_ref = fetch!(engine.state, ref).parent_ref
    Engine.JoinNode.update_new_child_node_with_matches_from_above(engine, parent_ref, ref)
  end

  @spec generate_bindings([Fact.t()], [FactTemplate.t()]) :: FactTemplate.bindings_map()
  defp generate_bindings(facts, conditions) do
    Enum.zip(facts, conditions)
    |> Enum.reduce(%{}, fn {fact, condition}, bindings ->
      Map.merge(bindings, FactTemplate.generate_bindings(condition, fact))
    end)
  end

  @spec add_or_remove_activation(engine, Activation.t(), :add | :remove) :: engine
  defp add_or_remove_activation(engine, activation, :add) do
    state = engine.state
    proposed_activations = MapSet.put(state.proposed_activations, activation)
    %{engine | state: %{state | proposed_activations: proposed_activations}}
  end

  defp add_or_remove_activation(engine, activation, :remove) do
    state = engine.state
    proposed_activations = MapSet.delete(state.proposed_activations, activation)
    %{engine | state: %{state | proposed_activations: proposed_activations}}
  end
end
