defmodule Ruler.Engine.AlphaMemory do
  alias Ruler.{
    FactTemplate,
    Engine,
    Fact,
    State
  }

  @type state :: State.t()
  @type engine :: Engine.t()
  @type mem_data :: State.AlphaMemory.t()
  @type ref :: State.AlphaMemory.ref()

  @spec fetch!(state, ref) :: mem_data
  def fetch!(state, ref) do
    State.RefMap.fetch!(state.alpha_memories, ref)
  end

  @spec build_or_share(engine, FactTemplate.t()) :: {engine, ref}
  def build_or_share(engine, condition) do
    {engine, constant_test_node_ref} =
      Engine.ConstantTestNode.build_or_share_lineage_for_condition(engine, condition)

    constant_test_node = Engine.ConstantTestNode.fetch!(engine.state, constant_test_node_ref)

    case constant_test_node.alpha_memory_ref do
      nil ->
        add_new_alpha_memory_to_constant_test_node(engine, constant_test_node_ref, condition)

      alpha_memory_ref ->
        {engine, alpha_memory_ref}
    end
  end

  @spec add_join_node!(engine, ref, State.JoinNode.ref()) :: engine
  def add_join_node!(engine, amem_ref, join_node_ref) do
    update!(engine, amem_ref, fn mem ->
      %{mem | join_node_refs: [join_node_ref | mem.join_node_refs]}
    end)
  end

  @spec activate(engine, ref, Fact.t(), :add | :remove) :: engine
  def activate(engine, ref, fact, op) do
    engine =
      update!(engine, ref, fn mem ->
        case op do
          :add ->
            %{mem | facts: MapSet.put(mem.facts, fact)}

          :remove ->
            %{mem | facts: MapSet.delete(mem.facts, fact)}
        end
      end)

    Enum.reduce(
      fetch!(engine.state, ref).join_node_refs,
      engine,
      fn join_node_ref, engine ->
        Engine.JoinNode.right_activate(engine, join_node_ref, fact, op)
      end
    )
  end

  @spec update!(engine, ref, (mem_data -> mem_data)) :: engine
  defp update!(engine, ref, f) do
    state = engine.state
    mems = State.RefMap.update!(state.alpha_memories, ref, f)
    state = %{state | alpha_memories: mems}
    %{engine | state: state}
  end

  @spec insert(engine, mem_data) :: {engine, ref}
  defp insert(engine, mem_data) do
    state = engine.state
    {mems, ref} = State.RefMap.insert(state.alpha_memories, mem_data)
    state = %{state | alpha_memories: mems}
    {%{engine | state: state}, ref}
  end

  @spec activate_on_existing_facts(engine, ref, FactTemplate.t()) :: engine
  defp activate_on_existing_facts(engine, ref, condition) do
    Enum.reduce(Map.keys(engine.state.facts), engine, fn fact, engine ->
      if FactTemplate.constant_tests_match_fact?(condition, fact) do
        activate(engine, ref, fact, :add)
      else
        engine
      end
    end)
  end

  @spec add_new_alpha_memory_to_constant_test_node(
          engine,
          Engine.ConstantTestNode.ref(),
          FactTemplate.t()
        ) ::
          {engine, ref}
  defp add_new_alpha_memory_to_constant_test_node(engine, constant_test_node_ref, condition) do
    {engine, mem_ref} = insert(engine, State.AlphaMemory.new())

    engine =
      engine
      |> Engine.ConstantTestNode.update_alpha_memory!(constant_test_node_ref, mem_ref)
      |> activate_on_existing_facts(mem_ref, condition)

    {engine, mem_ref}
  end
end
