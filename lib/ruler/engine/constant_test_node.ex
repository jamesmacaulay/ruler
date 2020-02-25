defmodule Ruler.Engine.ConstantTestNode do
  alias Ruler.{
    Condition,
    Engine,
    EventContext,
    Fact,
    State
  }

  @type state :: State.t()
  @type ctx :: EventContext.t()
  @type node_data :: State.ConstantTestNode.t()
  @type ref :: State.ConstantTestNode.ref()

  @spec fetch!(state, ref) :: node_data
  def fetch!(state, ref) do
    State.RefMap.fetch!(state.constant_test_nodes, ref)
  end

  # returns the new state along with the ref of the lowest child created
  @spec build_or_share_lineage_for_condition(ctx, Condition.t()) :: {ctx, ref}
  def build_or_share_lineage_for_condition(ctx, condition) do
    Enum.reduce(
      Condition.constant_tests(condition),
      {ctx, State.ConstantTestNode.top_node_ref()},
      fn {field_index, target_value}, {ctx, ref} ->
        build_or_share(ctx, ref, field_index, target_value)
      end
    )
  end

  @spec activate(ctx, ref, Fact.t(), :add | :remove) :: ctx
  def activate(ctx, ref, fact, op) do
    node = fetch!(ctx.state, ref)

    if State.ConstantTestNode.matches_fact?(node, fact) do
      ctx = activate_alpha_memory_if_present(ctx, node.alpha_memory_ref, fact, op)

      Enum.reduce(node.child_refs, ctx, fn child_ref, ctx ->
        activate(ctx, child_ref, fact, op)
      end)
    else
      ctx
    end
  end

  @spec update_alpha_memory!(ctx, ref, State.AlphaMemory.ref()) :: ctx
  def update_alpha_memory!(ctx, ref, mem_ref) do
    update!(ctx, ref, fn node ->
      %{node | alpha_memory_ref: mem_ref}
    end)
  end

  @spec activate_alpha_memory_if_present(
          ctx,
          State.AlphaMemory.ref() | nil,
          Fact.t(),
          :add | :remove
        ) :: ctx
  defp activate_alpha_memory_if_present(ctx, nil, _, _), do: ctx

  defp activate_alpha_memory_if_present(ctx, mem_ref, fact, op) do
    Engine.AlphaMemory.activate(ctx, mem_ref, fact, op)
  end

  @spec update!(ctx, ref, (node_data -> node_data)) :: ctx
  defp update!(ctx, ref, f) do
    nodes = State.RefMap.update!(ctx.state.constant_test_nodes, ref, f)
    state = %{ctx.state | constant_test_nodes: nodes}
    %{ctx | state: state}
  end

  @spec insert(ctx, node_data) :: {ctx, ref}
  defp insert(ctx, node_data) do
    {nodes, ref} = State.RefMap.insert(ctx.state.constant_test_nodes, node_data)
    state = %{ctx.state | constant_test_nodes: nodes}
    {%{ctx | state: state}, ref}
  end

  @spec add_child!(ctx, ref, Fact.field_index(), any) :: {ctx, ref}
  defp add_child!(ctx, parent_ref, field_index, target_value) do
    {ctx, child_ref} =
      insert(ctx, %State.ConstantTestNode{
        field_index: field_index,
        target_value: target_value,
        alpha_memory_ref: nil,
        child_refs: []
      })

    ctx =
      update!(ctx, parent_ref, fn parent_data ->
        %{parent_data | child_refs: [child_ref | parent_data.child_refs]}
      end)

    {ctx, child_ref}
  end

  @spec find_child!(state, ref, (node_data -> boolean)) :: ref | nil
  defp find_child!(state, parent_ref, pred) do
    parent = fetch!(state, parent_ref)

    Enum.find(parent.child_refs, fn child_ref ->
      pred.(fetch!(state, child_ref))
    end)
  end

  @spec build_or_share(ctx, ref, Fact.field_index(), any) :: {ctx, ref}
  defp build_or_share(ctx, parent_ref, field_index, target_value) do
    suitable_child_ref =
      find_child!(ctx.state, parent_ref, fn child ->
        child.field_index == field_index && child.target_value == target_value
      end)

    case suitable_child_ref do
      nil ->
        add_child!(ctx, parent_ref, field_index, target_value)

      _ ->
        {ctx, suitable_child_ref}
    end
  end
end
