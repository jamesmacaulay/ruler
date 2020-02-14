defmodule Ruler.Engine.AlphaMemory do
  alias Ruler.{
    Condition,
    Engine,
    Fact,
    State
  }

  @type state :: State.t()
  @type ctx :: EventContext.t()
  @type mem_data :: State.AlphaMemory.t()
  @type ref :: State.AlphaMemory.ref()

  @spec fetch!(state, ref) :: mem_data
  def fetch!(state, ref) do
    State.RefMap.fetch!(state.alpha_memories, ref)
  end

  @spec build_or_share(ctx, Condition.t()) :: {ctx, ref}
  def build_or_share(ctx, condition) do
    {ctx, constant_test_node_ref} =
      Engine.ConstantTestNode.build_or_share_lineage_for_condition(ctx, condition)

    constant_test_node = Engine.ConstantTestNode.fetch!(ctx.state, constant_test_node_ref)

    case constant_test_node.alpha_memory_ref do
      nil ->
        add_new_alpha_memory_to_constant_test_node(ctx, constant_test_node_ref, condition)

      alpha_memory_ref ->
        {ctx, alpha_memory_ref}
    end
  end

  @spec add_join_node!(ctx, ref, State.JoinNode.ref()) :: ctx
  def add_join_node!(ctx, amem_ref, join_node_ref) do
    update!(ctx, amem_ref, fn mem ->
      %{mem | join_node_refs: [join_node_ref | mem.join_node_refs]}
    end)
  end

  @spec activate(ctx, ref, Fact.t(), :add | :remove) :: ctx
  def activate(ctx, ref, fact, op) do
    ctx =
      update!(ctx, ref, fn mem ->
        case op do
          :add ->
            %{mem | facts: MapSet.put(mem.facts, fact)}

          :remove ->
            %{mem | facts: MapSet.delete(mem.facts, fact)}
        end
      end)

    Enum.reduce(
      fetch!(ctx.state, ref).join_node_refs,
      ctx,
      fn join_node_ref, ctx ->
        Engine.JoinNode.right_activate(ctx, join_node_ref, fact, op)
      end
    )
  end

  @spec update!(ctx, ref, (mem_data -> mem_data)) :: ctx
  defp update!(ctx, ref, f) do
    state = ctx.state
    mems = State.RefMap.update!(state.alpha_memories, ref, f)
    state = %{state | alpha_memories: mems}
    %{ctx | state: state}
  end

  @spec insert(ctx, mem_data) :: {ctx, ref}
  defp insert(ctx, mem_data) do
    state = ctx.state
    {mems, ref} = State.RefMap.insert(state.alpha_memories, mem_data)
    state = %{state | alpha_memories: mems}
    {%{ctx | state: state}, ref}
  end

  @spec activate_on_existing_facts(ctx, ref, Condition.t()) :: ctx
  defp activate_on_existing_facts(ctx, ref, condition) do
    Enum.reduce(Map.keys(ctx.state.facts), ctx, fn fact, ctx ->
      if Condition.constant_tests_match_fact?(condition, fact) do
        activate(ctx, ref, fact, :add)
      else
        ctx
      end
    end)
  end

  @spec add_new_alpha_memory_to_constant_test_node(
          ctx,
          Engine.ConstantTestNode.ref(),
          Condition.t()
        ) ::
          {ctx, ref}
  defp add_new_alpha_memory_to_constant_test_node(ctx, constant_test_node_ref, condition) do
    {ctx, mem_ref} = insert(ctx, State.AlphaMemory.new())

    ctx =
      ctx
      |> Engine.ConstantTestNode.update_alpha_memory!(constant_test_node_ref, mem_ref)
      |> activate_on_existing_facts(mem_ref, condition)

    {ctx, mem_ref}
  end
end
