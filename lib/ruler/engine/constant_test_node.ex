defmodule Ruler.Engine.ConstantTestNode do
  alias Ruler.{
    Condition,
    Engine,
    Fact,
    State
  }

  @type state :: State.t()
  @type node_data :: State.ConstantTestNode.t()
  @type ref :: State.ConstantTestNode.ref()

  @spec fetch!(state, ref) :: node_data
  def fetch!(state, ref) do
    State.RefMap.fetch!(state.constant_test_nodes, ref)
  end

  # returns the new state along with the ref of the lowest child created
  @spec build_or_share_lineage_for_condition(state, Condition.t()) :: {state, ref}
  def build_or_share_lineage_for_condition(state, condition) do
    Enum.reduce(
      Condition.constant_tests(condition),
      {state, state.alpha_top_node},
      fn {field_index, target_value}, {state, ref} ->
        build_or_share(state, ref, field_index, target_value)
      end
    )
  end

  @spec activate(state, ref, Fact.t()) :: state
  def activate(state, ref, fact) do
    node = fetch!(state, ref)

    if State.ConstantTestNode.matches_fact?(node, fact) do
      state = activate_alpha_memory_if_present(state, node.alpha_memory_ref, fact)

      Enum.reduce(node.child_refs, state, fn child_ref, state ->
        activate(state, child_ref, fact)
      end)
    else
      state
    end
  end

  @spec update_alpha_memory!(state, ref, State.AlphaMemory.ref()) :: state
  def update_alpha_memory!(state, ref, mem_ref) do
    update!(state, ref, fn node ->
      %{node | alpha_memory_ref: mem_ref}
    end)
  end

  @spec activate_alpha_memory_if_present(state, State.AlphaMemory.ref() | nil, Fact.t()) :: state
  defp activate_alpha_memory_if_present(state, nil, _), do: state

  defp activate_alpha_memory_if_present(state, mem_ref, fact) do
    Engine.AlphaMemory.activate(state, mem_ref, fact)
  end

  @spec update!(state, ref, (node_data -> node_data)) :: state
  defp update!(state, ref, f) do
    nodes = State.RefMap.update!(state.constant_test_nodes, ref, f)
    %{state | constant_test_nodes: nodes}
  end

  @spec insert(state, node_data) :: {state, ref}
  defp insert(state, node_data) do
    {nodes, ref} = State.RefMap.insert(state.constant_test_nodes, node_data)
    {%{state | constant_test_nodes: nodes}, ref}
  end

  @spec add_child!(state, ref, Fact.field_index(), any) :: {state, ref}
  defp add_child!(state, parent_ref, field_index, target_value) do
    {state, child_ref} =
      insert(state, %State.ConstantTestNode{
        field_index: field_index,
        target_value: target_value,
        alpha_memory_ref: nil,
        child_refs: []
      })

    state =
      update!(state, parent_ref, fn parent_data ->
        %{parent_data | child_refs: [child_ref | parent_data.child_refs]}
      end)

    {state, child_ref}
  end

  @spec find_child!(state, ref, (node_data -> boolean)) :: ref | nil
  defp find_child!(state, parent_ref, pred) do
    parent = fetch!(state, parent_ref)

    Enum.find(parent.child_refs, fn child_ref ->
      pred.(fetch!(state, child_ref))
    end)
  end

  @spec build_or_share(state, ref, Fact.field_index(), any) :: {state, ref}
  defp build_or_share(state, parent_ref, field_index, target_value) do
    suitable_child_ref =
      find_child!(state, parent_ref, fn child ->
        child.field_index == field_index && child.target_value == target_value
      end)

    case suitable_child_ref do
      nil ->
        add_child!(state, parent_ref, field_index, target_value)

      _ ->
        {state, suitable_child_ref}
    end
  end
end
