defmodule Ruler.Engine.ActivationNode do
  alias Ruler.{
    Activation,
    Clause,
    Condition,
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
    State.RefMap.fetch!(state.activation_nodes, ref)
  end

  @spec build_all(engine, rule) :: {engine, [ref]}
  def build_all(engine, rule) do
    condition_matrix = Clause.condition_matrix_from_clause(rule.clauses)

    {engine, refs} =
      Enum.reduce(condition_matrix, {engine, []}, fn conditions, {engine, refs} ->
        {engine, ref} = build(engine, rule, conditions)
        {engine, [ref | refs]}
      end)

    {engine, Enum.reverse(refs)}
  end

  @spec build(engine, rule, [Condition.t()]) :: {engine, ref}
  def build(engine, rule, conditions) do
    {engine, parent_ref} =
      Engine.JoinNode.build_or_share_lineage_for_conditions(engine, conditions)

    {engine, ref} =
      insert(engine, %State.ActivationNode{
        parent_ref: parent_ref,
        rule_id: rule.id,
        conditions: conditions
      })

    engine =
      engine
      |> add_child_ref!(parent_ref, ref)
      |> update_new_node_with_matches_from_above(ref)

    {engine, ref}
  end

  def add_child_ref!(engine, parent_ref = {:join_node_ref, _}, ref) do
    Engine.JoinNode.add_child_ref!(engine, parent_ref, ref)
  end

  def add_child_ref!(engine, parent_ref = {:negative_node_ref, _}, ref) do
    Engine.NegativeNode.add_child_ref!(engine, parent_ref, ref)
  end

  @spec left_activate(engine, ref, partial_activation, Fact.t() | nil, :add | :remove) :: engine
  def left_activate(engine, ref, partial_activation, fact, op) do
    node = fetch!(engine.state, ref)
    facts = Enum.reverse([fact | partial_activation])

    add_or_remove_activation(
      engine,
      %Activation{
        rule_id: node.rule_id,
        conditions: node.conditions,
        facts: facts,
        bindings: generate_bindings(facts, node.conditions)
      },
      op
    )
  end

  @spec insert(engine, node_data) :: {engine, ref}
  defp insert(engine, node_data) do
    state = engine.state
    {nodes, ref} = State.RefMap.insert(state.activation_nodes, node_data)
    state = %{state | activation_nodes: nodes}
    {%{engine | state: state}, ref}
  end

  @spec update_new_node_with_matches_from_above(engine, ref) :: engine
  defp update_new_node_with_matches_from_above(engine, ref) do
    parent_ref = fetch!(engine.state, ref).parent_ref

    case parent_ref do
      {:join_node_ref, _} ->
        Engine.JoinNode.update_new_child_node_with_matches_from_above(engine, parent_ref, ref)

      {:negative_node_ref, _} ->
        Engine.NegativeNode.update_new_child_node_with_matches_from_above(engine, parent_ref, ref)
    end
  end

  @spec generate_bindings([Fact.t()], [Condition.t()]) :: FactTemplate.bindings_map()
  defp generate_bindings(facts, conditions) do
    Enum.zip(facts, conditions)
    |> Enum.reduce(%{}, fn {fact, condition}, bindings ->
      case fact do
        nil -> bindings
        _ -> Map.merge(bindings, Condition.generate_bindings(condition, fact))
      end
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
