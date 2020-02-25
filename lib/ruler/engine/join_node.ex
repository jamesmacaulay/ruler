defmodule Ruler.Engine.JoinNode do
  alias Ruler.{
    Engine,
    EventContext,
    Fact,
    State
  }

  @type state :: State.t()
  @type ctx :: EventContext.t()
  @type node_data :: State.JoinNode.t()
  @type ref :: State.JoinNode.ref()
  @type child_ref :: State.BetaMemory.ref() | State.ActivationNode.ref()
  @type partial_activation :: State.BetaMemory.partial_activation()

  @spec fetch!(state, ref) :: node_data
  def fetch!(state, ref) do
    State.RefMap.fetch!(state.join_nodes, ref)
  end

  # when a new partial activation is added to the parent beta memory
  @spec left_activate(ctx, ref, partial_activation, :add | :remove) :: ctx
  def left_activate(ctx, ref, partial_activation, op) do
    state = ctx.state
    node = fetch!(state, ref)
    alpha_memory = Engine.AlphaMemory.fetch!(state, node.alpha_memory_ref)

    Enum.reduce(alpha_memory.facts, ctx, fn fact, ctx ->
      compare_and_activate_children(ctx, node, partial_activation, fact, op)
    end)
  end

  @spec right_activate(ctx, ref, Fact.t(), :add | :remove) :: ctx
  def right_activate(ctx, ref, fact, op) do
    state = ctx.state
    node = fetch!(state, ref)
    parent = Engine.BetaMemory.fetch!(state, node.parent_ref)

    Enum.reduce(parent.partial_activations, ctx, fn partial_activation, ctx ->
      compare_and_activate_children(ctx, node, partial_activation, fact, op)
    end)
  end

  @spec find_beta_memory_child_ref!(state, ref) :: State.BetaMemory.ref() | nil
  def find_beta_memory_child_ref!(state, ref) do
    Enum.find(fetch!(state, ref).child_refs, fn child_ref ->
      match?({:beta_memory_ref, _}, child_ref)
    end)
  end

  @spec build_or_share_lineage_for_conditions(ctx, [Condition.t()]) :: {ctx, ref}
  def build_or_share_lineage_for_conditions(ctx, conditions) do
    [first_condition | rest_conditions] = conditions

    comparisons = State.JoinNode.comparisons_from_condition(first_condition, [])
    {ctx, amem_ref} = Engine.AlphaMemory.build_or_share(ctx, first_condition)

    {ctx, join_ref} = build_or_share(ctx, State.BetaMemory.top_node_ref(), amem_ref, comparisons)

    {ctx, join_ref, _} =
      Enum.reduce(
        rest_conditions,
        {ctx, join_ref, [first_condition]},
        fn condition, {ctx, current_join_node_ref, earlier_conditions} ->
          {ctx, current_beta_memory_ref} =
            Engine.BetaMemory.build_or_share(ctx, current_join_node_ref)

          comparisons = State.JoinNode.comparisons_from_condition(condition, earlier_conditions)

          {ctx, amem_ref} = Engine.AlphaMemory.build_or_share(ctx, condition)

          {ctx, current_join_node_ref} =
            build_or_share(ctx, current_beta_memory_ref, amem_ref, comparisons)

          {ctx, current_join_node_ref, [condition | earlier_conditions]}
        end
      )

    {ctx, join_ref}
  end

  @spec add_child_ref!(ctx, ref, child_ref) :: ctx
  def add_child_ref!(ctx, ref, child_ref) do
    update!(ctx, ref, fn node ->
      %{node | child_refs: [child_ref | node.child_refs]}
    end)
  end

  @spec update_new_child_node_with_matches_from_above(ctx, ref, child_ref) :: ctx
  def update_new_child_node_with_matches_from_above(ctx, ref, child_ref) do
    state = ctx.state
    node = fetch!(state, ref)
    amem = Engine.AlphaMemory.fetch!(state, node.alpha_memory_ref)
    saved_child_refs = node.child_refs

    ctx = update!(ctx, ref, fn node -> %{node | child_refs: [child_ref]} end)

    ctx =
      Enum.reduce(amem.facts, ctx, fn fact, ctx ->
        right_activate(ctx, ref, fact, :add)
      end)

    update!(ctx, ref, fn node -> %{node | child_refs: saved_child_refs} end)
  end

  @spec update!(ctx, ref, (node_data -> node_data)) :: ctx
  defp update!(ctx, ref, f) do
    state = ctx.state
    nodes = State.RefMap.update!(state.join_nodes, ref, f)
    state = %{state | join_nodes: nodes}
    %{ctx | state: state}
  end

  @spec insert(ctx, node_data) :: {ctx, ref}
  defp insert(ctx, node_data) do
    state = ctx.state
    {nodes, ref} = State.RefMap.insert(state.join_nodes, node_data)
    state = %{state | join_nodes: nodes}
    {%{ctx | state: state}, ref}
  end

  @spec build_or_share(ctx, State.BetaMemory.ref(), State.AlphaMemory.ref(), [Comparison.t()]) ::
          {ctx, ref}
  defp build_or_share(ctx, parent_ref, amem_ref, comparisons) do
    suitable_child_ref =
      Engine.BetaMemory.find_child!(ctx.state, parent_ref, fn child ->
        child.alpha_memory_ref == amem_ref && child.comparisons == comparisons
      end)

    case suitable_child_ref do
      nil ->
        {ctx, ref} =
          insert(ctx, %State.JoinNode{
            parent_ref: parent_ref,
            child_refs: [],
            alpha_memory_ref: amem_ref,
            comparisons: comparisons
          })

        ctx =
          ctx
          |> Engine.AlphaMemory.add_join_node!(amem_ref, ref)
          |> Engine.BetaMemory.add_join_node!(parent_ref, ref)

        {ctx, ref}

      _ ->
        {ctx, suitable_child_ref}
    end
  end

  @spec compare_and_activate_children(
          ctx,
          node_data,
          partial_activation,
          Fact.t(),
          :add | :remove
        ) ::
          ctx
  defp compare_and_activate_children(ctx, node, partial_activation, fact, op) do
    if State.JoinNode.perform_join_comparisons(node.comparisons, partial_activation, fact) do
      Enum.reduce(node.child_refs, ctx, fn child_ref, ctx ->
        left_activate_child(ctx, child_ref, partial_activation, fact, op)
      end)
    else
      ctx
    end
  end

  @spec left_activate_child(ctx, child_ref, partial_activation, Fact.t(), :add | :remove) ::
          ctx
  defp left_activate_child(ctx, child_ref, partial_activation, fact, op) do
    case child_ref do
      {:beta_memory_ref, _} ->
        Engine.BetaMemory.left_activate(ctx, child_ref, partial_activation, fact, op)

      {:activation_node_ref, _} ->
        Engine.ActivationNode.left_activate(ctx, child_ref, partial_activation, fact, op)
    end
  end
end
