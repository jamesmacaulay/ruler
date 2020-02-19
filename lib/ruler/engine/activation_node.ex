defmodule Ruler.Engine.ActivationNode do
  alias Ruler.{
    Activation,
    Condition,
    Engine,
    EventContext,
    Fact,
    Rule,
    State
  }

  @type state :: State.t()
  @type ctx :: EventContext.t()
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

  @spec build(ctx, rule) :: ctx
  def build(ctx, rule) do
    {ctx, parent_ref} =
      Engine.JoinNode.build_or_share_lineage_for_conditions(ctx, rule.conditions)

    {ctx, ref} =
      insert(ctx, %State.ActivationNode{
        parent_ref: parent_ref,
        rule_id: rule.id,
        activations: MapSet.new()
      })

    ctx
    |> Engine.JoinNode.add_child_ref!(parent_ref, ref)
    |> update_new_node_with_matches_from_above(ref)
  end

  @spec left_activate(ctx, ref, partial_activation, Fact.t(), :add | :remove) :: ctx
  def left_activate(ctx, ref, partial_activation, fact, op) do
    rule_id = State.ActivationNode.rule_id_from_ref(ref)
    facts = Enum.reverse([fact | partial_activation])
    rule = Map.fetch!(ctx.state.rules, rule_id)

    add_or_remove_activation(
      ctx,
      ref,
      %Activation{
        rule_id: rule_id,
        facts: facts,
        bindings: generate_bindings(facts, rule.conditions)
      },
      op
    )
  end

  @spec insert(ctx, node_data) :: {ctx, ref}
  defp insert(ctx, node_data) do
    state = ctx.state
    ref = State.ActivationNode.ref_from_rule_id(node_data.rule_id)
    nodes = Map.put(state.activation_nodes, ref, node_data)
    state = %{state | activation_nodes: nodes}
    {%{ctx | state: state}, ref}
  end

  @spec update!(ctx, ref, (node_data -> node_data)) :: ctx
  defp update!(ctx, ref, f) do
    state = ctx.state
    nodes = Map.update!(state.activation_nodes, ref, f)
    state = %{state | activation_nodes: nodes}
    %{ctx | state: state}
  end

  @spec update_new_node_with_matches_from_above(ctx, ref) :: ctx
  defp update_new_node_with_matches_from_above(ctx, ref) do
    parent_ref = fetch!(ctx.state, ref).parent_ref
    Engine.JoinNode.update_new_child_node_with_matches_from_above(ctx, parent_ref, ref)
  end

  @spec generate_bindings([Fact.t()], [Condition.t()]) :: Condition.bindings_map()
  defp generate_bindings(facts, conditions) do
    Enum.zip(facts, conditions)
    |> Enum.reduce(%{}, fn {fact, condition}, bindings ->
      Map.merge(bindings, Condition.generate_bindings(condition, fact))
    end)
  end

  @spec add_or_remove_activation(ctx, ref, Activation.t(), :add | :remove) :: ctx
  defp add_or_remove_activation(ctx, ref, activation, :add) do
    activation_events = [{:activate, activation} | ctx.activation_events]
    ctx = %{ctx | activation_events: activation_events}

    update!(ctx, ref, fn node ->
      %{
        node
        | activations: MapSet.put(node.activations, activation)
      }
    end)
  end

  defp add_or_remove_activation(ctx, ref, activation, :remove) do
    activation_events = [{:deactivate, activation} | ctx.activation_events]
    ctx = %{ctx | activation_events: activation_events}

    update!(ctx, ref, fn node ->
      %{
        node
        | activations: MapSet.delete(node.activations, activation)
      }
    end)
  end
end
