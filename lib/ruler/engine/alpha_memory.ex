defmodule Ruler.Engine.AlphaMemory do
  alias Ruler.{
    Condition,
    Engine,
    Fact,
    State
  }

  @type state :: State.t()
  @type mem_data :: State.AlphaMemory.t()
  @type ref :: State.AlphaMemory.ref()

  @spec fetch!(state, ref) :: mem_data
  def fetch!(state, ref) do
    State.RefMap.fetch!(state.alpha_memories, ref)
  end

  @spec build_or_share(state, Condition.t()) :: {state, ref}
  def build_or_share(state, condition) do
    {state, constant_test_node_ref} =
      Engine.ConstantTestNode.build_or_share_lineage_for_condition(state, condition)

    constant_test_node = Engine.ConstantTestNode.fetch!(state, constant_test_node_ref)

    case constant_test_node.alpha_memory do
      nil ->
        add_new_alpha_memory_to_constant_test_node(state, constant_test_node_ref, condition)

      alpha_memory_ref ->
        {state, alpha_memory_ref}
    end
  end

  @spec add_join_node!(state, ref, State.JoinNode.ref()) :: state
  def add_join_node!(state, amem_ref, join_node_ref) do
    update!(state, amem_ref, fn mem ->
      %{mem | join_nodes: [join_node_ref | mem.join_nodes]}
    end)
  end

  @spec activate(state, ref, Fact.t()) :: state
  def activate(state, ref, fact) do
    state =
      update!(state, ref, fn mem ->
        %{mem | facts: MapSet.put(mem.facts, fact)}
      end)

    Enum.reduce(
      fetch!(state, ref).join_nodes,
      state,
      fn join_node_ref, state ->
        Engine.JoinNode.right_activate(state, join_node_ref, fact)
      end
    )
  end

  @spec update!(state, ref, (mem_data -> mem_data)) :: state
  defp update!(state, ref, f) do
    mems = State.RefMap.update!(state.alpha_memories, ref, f)
    %{state | alpha_memories: mems}
  end

  @spec insert(state, mem_data) :: {state, ref}
  defp insert(state, mem_data) do
    {mems, ref} = State.RefMap.insert(state.alpha_memories, mem_data)
    {%{state | alpha_memories: mems}, ref}
  end

  @spec activate_on_existing_facts(state, ref, Condition.t()) :: state
  defp activate_on_existing_facts(state, ref, condition) do
    Enum.reduce(Map.keys(state.facts), state, fn fact, state ->
      if Condition.constant_tests_match_fact?(condition, fact) do
        activate(state, ref, fact)
      else
        state
      end
    end)
  end

  @spec add_new_alpha_memory_to_constant_test_node(
          state,
          Engine.ConstantTestNode.ref(),
          Condition.t()
        ) ::
          {state, ref}
  defp add_new_alpha_memory_to_constant_test_node(state, constant_test_node_ref, condition) do
    {state, mem_ref} = insert(state, State.AlphaMemory.new())

    state =
      state
      |> Engine.ConstantTestNode.update_alpha_memory!(constant_test_node_ref, mem_ref)
      |> activate_on_existing_facts(mem_ref, condition)

    {state, mem_ref}
  end
end
