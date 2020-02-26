defmodule Ruler.Engine.ConstantTestNode do
  alias Ruler.{
    Condition,
    Engine,
    Fact,
    State
  }

  @type state :: State.t()
  @type engine :: Engine.t()
  @type node_data :: State.ConstantTestNode.t()
  @type ref :: State.ConstantTestNode.ref()

  @spec fetch!(state, ref) :: node_data
  def fetch!(state, ref) do
    State.RefMap.fetch!(state.constant_test_nodes, ref)
  end

  # returns the new state along with the ref of the lowest child created
  @spec build_or_share_lineage_for_condition(engine, Condition.t()) :: {engine, ref}
  def build_or_share_lineage_for_condition(engine, condition) do
    Enum.reduce(
      Condition.constant_tests(condition),
      {engine, State.ConstantTestNode.top_node_ref()},
      fn {field_index, target_value}, {engine, ref} ->
        build_or_share(engine, ref, field_index, target_value)
      end
    )
  end

  @spec activate(engine, ref, Fact.t(), :add | :remove) :: engine
  def activate(engine, ref, fact, op) do
    node = fetch!(engine.state, ref)

    if State.ConstantTestNode.matches_fact?(node, fact) do
      engine = activate_alpha_memory_if_present(engine, node.alpha_memory_ref, fact, op)

      Enum.reduce(node.child_refs, engine, fn child_ref, engine ->
        activate(engine, child_ref, fact, op)
      end)
    else
      engine
    end
  end

  @spec update_alpha_memory!(engine, ref, State.AlphaMemory.ref()) :: engine
  def update_alpha_memory!(engine, ref, mem_ref) do
    update!(engine, ref, fn node ->
      %{node | alpha_memory_ref: mem_ref}
    end)
  end

  @spec activate_alpha_memory_if_present(
          engine,
          State.AlphaMemory.ref() | nil,
          Fact.t(),
          :add | :remove
        ) :: engine
  defp activate_alpha_memory_if_present(engine, nil, _, _), do: engine

  defp activate_alpha_memory_if_present(engine, mem_ref, fact, op) do
    Engine.AlphaMemory.activate(engine, mem_ref, fact, op)
  end

  @spec update!(engine, ref, (node_data -> node_data)) :: engine
  defp update!(engine, ref, f) do
    nodes = State.RefMap.update!(engine.state.constant_test_nodes, ref, f)
    state = %{engine.state | constant_test_nodes: nodes}
    %{engine | state: state}
  end

  @spec insert(engine, node_data) :: {engine, ref}
  defp insert(engine, node_data) do
    {nodes, ref} = State.RefMap.insert(engine.state.constant_test_nodes, node_data)
    state = %{engine.state | constant_test_nodes: nodes}
    {%{engine | state: state}, ref}
  end

  @spec add_child!(engine, ref, Fact.field_index(), any) :: {engine, ref}
  defp add_child!(engine, parent_ref, field_index, target_value) do
    {engine, child_ref} =
      insert(engine, %State.ConstantTestNode{
        field_index: field_index,
        target_value: target_value,
        alpha_memory_ref: nil,
        child_refs: []
      })

    engine =
      update!(engine, parent_ref, fn parent_data ->
        %{parent_data | child_refs: [child_ref | parent_data.child_refs]}
      end)

    {engine, child_ref}
  end

  @spec find_child!(state, ref, (node_data -> boolean)) :: ref | nil
  defp find_child!(state, parent_ref, pred) do
    parent = fetch!(state, parent_ref)

    Enum.find(parent.child_refs, fn child_ref ->
      pred.(fetch!(state, child_ref))
    end)
  end

  @spec build_or_share(engine, ref, Fact.field_index(), any) :: {engine, ref}
  defp build_or_share(engine, parent_ref, field_index, target_value) do
    suitable_child_ref =
      find_child!(engine.state, parent_ref, fn child ->
        child.field_index == field_index && child.target_value == target_value
      end)

    case suitable_child_ref do
      nil ->
        add_child!(engine, parent_ref, field_index, target_value)

      _ ->
        {engine, suitable_child_ref}
    end
  end
end
