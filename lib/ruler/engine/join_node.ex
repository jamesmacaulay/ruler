defmodule Ruler.Engine.JoinNode do
  alias Ruler.{
    Engine,
    Fact,
    State
  }

  @type state :: State.t()
  @type node_data :: State.JoinNode.t()
  @type ref :: State.JoinNode.ref()
  @type child_ref :: State.BetaMemory.ref() | State.ActivationNode.ref()
  @type partial_activation :: State.BetaMemory.partial_activation()

  @spec fetch!(state, ref) :: node_data
  def fetch!(state, ref) do
    State.RefMap.fetch!(state.join_nodes, ref)
  end

  # when a new partial activation is added to the parent beta memory
  @spec left_activate(state, ref, partial_activation) :: state
  def left_activate(state, ref, partial_activation) do
    node = fetch!(state, ref)
    alpha_memory = Engine.AlphaMemory.fetch!(state, node.alpha_memory)

    Enum.reduce(alpha_memory.facts, state, fn fact, state ->
      compare_and_activate_children(state, node, partial_activation, fact)
    end)
  end

  @spec right_activate(state, ref, Fact.t()) :: state
  def right_activate(state, ref, fact) do
    node = fetch!(state, ref)
    parent = Engine.BetaMemory.fetch!(state, node.parent)

    # fold parent.partial_activations into init_state by performing comparisons and left activations
    Enum.reduce(parent.partial_activations, state, fn partial_activation, state ->
      compare_and_activate_children(state, node, partial_activation, fact)
    end)
  end

  @spec find_beta_memory_child_ref!(state, ref) :: State.BetaMemory.ref() | nil
  def find_beta_memory_child_ref!(state, ref) do
    Enum.find(fetch!(state, ref).children, fn child_ref ->
      match?({:beta_memory_ref, _}, child_ref)
    end)
  end

  @spec build_or_share_lineage_for_conditions(state, [Condition.t()]) :: {state, ref}
  def build_or_share_lineage_for_conditions(state, conditions) do
    [first_condition | rest_conditions] = conditions

    comparisons = State.JoinNode.comparisons_from_condition(first_condition, [])
    {state, amem_ref} = Engine.AlphaMemory.build_or_share(state, first_condition)

    {state, join_ref} = build_or_share(state, state.beta_top_node, amem_ref, comparisons)

    {state, join_ref, _} =
      Enum.reduce(
        rest_conditions,
        {state, join_ref, [first_condition]},
        fn condition, {state, current_join_node_ref, earlier_conditions} ->
          {state, current_beta_memory_ref} =
            Engine.BetaMemory.build_or_share(state, current_join_node_ref)

          comparisons = State.JoinNode.comparisons_from_condition(condition, earlier_conditions)
          {state, amem_ref} = Engine.AlphaMemory.build_or_share(state, condition)

          {state, current_join_node_ref} =
            build_or_share(state, current_beta_memory_ref, amem_ref, comparisons)

          {state, current_join_node_ref, [condition | earlier_conditions]}
        end
      )

    {state, join_ref}
  end

  @spec add_child_ref!(state, ref, child_ref) :: state
  def add_child_ref!(state, ref, child_ref) do
    update!(state, ref, fn node ->
      %{node | children: [child_ref | node.children]}
    end)
  end

  @spec update_new_child_node_with_matches_from_above(state, ref, child_ref) :: state
  def update_new_child_node_with_matches_from_above(state, ref, child_ref) do
    node = fetch!(state, ref)
    amem = Engine.AlphaMemory.fetch!(state, node.alpha_memory)
    saved_children = node.children

    state = update!(state, ref, fn node -> %{node | children: [child_ref]} end)

    state =
      Enum.reduce(amem.facts, state, fn fact, state ->
        right_activate(state, ref, fact)
      end)

    update!(state, ref, fn node -> %{node | children: saved_children} end)
  end

  @spec update!(state, ref, (node_data -> node_data)) :: state
  defp update!(state, ref, f) do
    nodes = State.RefMap.update!(state.join_nodes, ref, f)
    %{state | join_nodes: nodes}
  end

  @spec insert(state, node_data) :: {state, ref}
  defp insert(state, node_data) do
    {nodes, ref} = State.RefMap.insert(state.join_nodes, node_data)
    {%{state | join_nodes: nodes}, ref}
  end

  @spec build_or_share(state, State.BetaMemory.ref(), State.AlphaMemory.ref(), [Comparison.t()]) ::
          {state, ref}
  defp build_or_share(state, parent_ref, amem_ref, comparisons) do
    suitable_child_ref =
      Engine.BetaMemory.find_child!(state, parent_ref, fn child ->
        child.alpha_memory == amem_ref && child.comparisons == comparisons
      end)

    case suitable_child_ref do
      nil ->
        {state, ref} =
          insert(state, %State.JoinNode{
            parent: parent_ref,
            children: [],
            alpha_memory: amem_ref,
            comparisons: comparisons
          })

        state =
          state
          |> Engine.AlphaMemory.add_join_node!(amem_ref, ref)
          |> Engine.BetaMemory.add_join_node!(parent_ref, ref)

        {state, ref}

      _ ->
        {state, suitable_child_ref}
    end
  end

  @spec compare_and_activate_children(state, node_data, partial_activation, Fact.t()) ::
          state
  defp compare_and_activate_children(state, node, partial_activation, fact) do
    if State.JoinNode.perform_join_comparisons(node.comparisons, partial_activation, fact) do
      Enum.reduce(node.children, state, fn child_ref, state ->
        left_activate_child(state, child_ref, partial_activation, fact)
      end)
    else
      state
    end
  end

  @spec left_activate_child(state, child_ref, partial_activation, Fact.t()) ::
          state
  defp left_activate_child(state, child_ref, partial_activation, fact) do
    case child_ref do
      {:beta_memory_ref, _} ->
        Engine.BetaMemory.left_activate(state, child_ref, partial_activation, fact)

      {:activation_node_ref, _} ->
        Engine.ActivationNode.left_activate(state, child_ref, partial_activation, fact)
    end
  end
end
