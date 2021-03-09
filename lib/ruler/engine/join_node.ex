defmodule Ruler.Engine.JoinNode do
  alias Ruler.{
    Condition,
    Engine,
    Fact,
    State
  }

  @type state :: State.t()
  @type engine :: Engine.t()
  @type node_data :: State.JoinNode.t()
  @type ref :: State.JoinNode.ref()
  @type child_ref :: State.JoinNode.child_ref()
  @type partial_activation :: State.BetaMemory.partial_activation()

  @spec fetch!(state, ref) :: node_data
  def fetch!(state, ref) do
    State.RefMap.fetch!(state.join_nodes, ref)
  end

  # when a new partial activation is added to the parent beta memory
  @spec left_activate(engine, ref, partial_activation, :add | :remove) :: engine
  def left_activate(engine, ref, partial_activation, op) do
    state = engine.state
    node = fetch!(state, ref)
    alpha_memory = Engine.AlphaMemory.fetch!(state, node.alpha_memory_ref)

    Enum.reduce(alpha_memory.facts, engine, fn fact, engine ->
      compare_and_activate_children(engine, node, partial_activation, fact, op)
    end)
  end

  @spec right_activate(engine, ref, Fact.t(), :add | :remove) :: engine
  def right_activate(engine, ref, fact, op) do
    state = engine.state
    node = fetch!(state, ref)
    parent = Engine.BetaMemory.fetch!(state, node.parent_ref)

    Enum.reduce(parent.partial_activations, engine, fn partial_activation, engine ->
      compare_and_activate_children(engine, node, partial_activation, fact, op)
    end)
  end

  @spec find_beta_memory_child_ref!(state, ref) :: State.BetaMemory.ref() | nil
  def find_beta_memory_child_ref!(state, ref) do
    Enum.find(fetch!(state, ref).child_refs, fn child_ref ->
      match?({:beta_memory_ref, _}, child_ref)
    end)
  end

  @spec build_or_share_lineage_for_conditions(engine, [Condition.t()]) :: {engine, ref}
  def build_or_share_lineage_for_conditions(engine, conditions) do
    [first_condition | rest_conditions] = conditions

    comparisons = State.JoinNode.comparisons_from_condition(first_condition, [])
    {engine, amem_ref} = Engine.AlphaMemory.build_or_share(engine, first_condition)

    {engine, join_ref} =
      case first_condition do
        {:known, _} ->
          build_or_share(engine, State.BetaMemory.top_node_ref(), amem_ref, comparisons)

        {:not_known, _} ->
          Engine.NegativeNode.build_or_share(
            engine,
            State.BetaMemory.top_node_ref(),
            amem_ref,
            comparisons
          )
      end

    {engine, join_ref, _} =
      Enum.reduce(
        rest_conditions,
        {engine, join_ref, [first_condition]},
        &reduce_conditions_into_node_lineage/2
      )

    {engine, join_ref}
  end

  defp reduce_conditions_into_node_lineage(
         condition = {:known, _},
         {engine, current_join_node_ref, earlier_conditions}
       ) do
    {engine, current_beta_memory_ref} =
      Engine.BetaMemory.build_or_share(engine, current_join_node_ref)

    comparisons = State.JoinNode.comparisons_from_condition(condition, earlier_conditions)

    {engine, amem_ref} = Engine.AlphaMemory.build_or_share(engine, condition)

    {engine, current_join_node_ref} =
      build_or_share(engine, current_beta_memory_ref, amem_ref, comparisons)

    {engine, current_join_node_ref, [condition | earlier_conditions]}
  end

  defp reduce_conditions_into_node_lineage(
         condition = {:not_known, _},
         {engine, current_join_node_ref, earlier_conditions}
       ) do
    comparisons = State.JoinNode.comparisons_from_condition(condition, earlier_conditions)
    {engine, amem_ref} = Engine.AlphaMemory.build_or_share(engine, condition)

    {engine, current_join_node_ref} =
      Engine.NegativeNode.build_or_share(engine, current_join_node_ref, amem_ref, comparisons)

    {engine, current_join_node_ref, [condition | earlier_conditions]}
  end

  @spec add_child_ref!(engine, ref, child_ref) :: engine
  def add_child_ref!(engine, ref, child_ref) do
    update!(engine, ref, fn node ->
      %{node | child_refs: [child_ref | node.child_refs]}
    end)
  end

  @spec update_new_child_node_with_matches_from_above(engine, ref, child_ref) :: engine
  def update_new_child_node_with_matches_from_above(engine, ref, child_ref) do
    state = engine.state
    node = fetch!(state, ref)
    amem = Engine.AlphaMemory.fetch!(state, node.alpha_memory_ref)
    saved_child_refs = node.child_refs

    engine = update!(engine, ref, fn node -> %{node | child_refs: [child_ref]} end)

    engine =
      Enum.reduce(amem.facts, engine, fn fact, engine ->
        right_activate(engine, ref, fact, :add)
      end)

    update!(engine, ref, fn node -> %{node | child_refs: saved_child_refs} end)
  end

  @spec update!(engine, ref, (node_data -> node_data)) :: engine
  defp update!(engine, ref, f) do
    state = engine.state
    nodes = State.RefMap.update!(state.join_nodes, ref, f)
    state = %{state | join_nodes: nodes}
    %{engine | state: state}
  end

  @spec insert(engine, node_data) :: {engine, ref}
  defp insert(engine, node_data) do
    state = engine.state
    {nodes, ref} = State.RefMap.insert(state.join_nodes, node_data)
    state = %{state | join_nodes: nodes}
    {%{engine | state: state}, ref}
  end

  @spec build_or_share(engine, State.BetaMemory.ref(), State.AlphaMemory.ref(), [Comparison.t()]) ::
          {engine, ref}
  defp build_or_share(engine, parent_ref, amem_ref, comparisons) do
    suitable_child_ref =
      Engine.BetaMemory.find_join_node_child!(engine.state, parent_ref, fn child ->
        child.alpha_memory_ref == amem_ref && child.comparisons == comparisons
      end)

    case suitable_child_ref do
      nil ->
        {engine, ref} =
          insert(engine, %State.JoinNode{
            parent_ref: parent_ref,
            child_refs: [],
            alpha_memory_ref: amem_ref,
            comparisons: comparisons
          })

        engine =
          engine
          |> Engine.AlphaMemory.add_beta_node!(amem_ref, ref)
          |> Engine.BetaMemory.add_child_node!(parent_ref, ref)

        {engine, ref}

      _ ->
        {engine, suitable_child_ref}
    end
  end

  @spec compare_and_activate_children(
          engine,
          node_data,
          partial_activation,
          Fact.t(),
          :add | :remove
        ) ::
          engine
  defp compare_and_activate_children(engine, node, partial_activation, fact, op) do
    if State.JoinNode.perform_join_comparisons(node.comparisons, partial_activation, fact) do
      Enum.reduce(node.child_refs, engine, fn child_ref, engine ->
        left_activate_child(engine, child_ref, partial_activation, fact, op)
      end)
    else
      engine
    end
  end

  @spec left_activate_child(engine, child_ref, partial_activation, Fact.t() | nil, :add | :remove) ::
          engine
  def left_activate_child(engine, child_ref, partial_activation, fact, op) do
    case child_ref do
      {:beta_memory_ref, _} ->
        Engine.BetaMemory.left_activate(engine, child_ref, partial_activation, fact, op)

      {:activation_node_ref, _} ->
        Engine.ActivationNode.left_activate(engine, child_ref, partial_activation, fact, op)

      {:negative_node_ref, _} ->
        Engine.NegativeNode.left_activate(engine, child_ref, partial_activation, fact, op)
    end
  end

  @spec find_negative_node_child!(state, ref, (State.NegativeNode.t() -> boolean)) ::
          State.NegativeNode.ref() | nil
  def find_negative_node_child!(state, parent_ref, pred) do
    parent = fetch!(state, parent_ref)

    Enum.find(parent.child_refs, fn child_ref ->
      match?({:negative_node_ref, _}, child_ref) &&
        pred.(Engine.NegativeNode.fetch!(state, child_ref))
    end)
  end
end
