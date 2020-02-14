defmodule Ruler.Engine.BetaMemory do
  alias Ruler.{
    Engine,
    Fact,
    State
  }

  @type state :: State.t()
  @type ctx :: EventContext.t()
  @type mem_data :: State.BetaMemory.t()
  @type ref :: State.BetaMemory.ref()
  @type partial_activation :: State.BetaMemory.partial_activation()

  @spec fetch!(state, ref) :: mem_data
  def fetch!(state, ref) do
    State.RefMap.fetch!(state.beta_memories, ref)
  end

  @spec build_or_share(ctx, State.JoinNode.ref()) :: {ctx, ref}
  def build_or_share(ctx, parent_ref) do
    suitable_child_ref = Engine.JoinNode.find_beta_memory_child_ref!(ctx.state, parent_ref)

    case suitable_child_ref do
      nil ->
        {ctx, ref} = insert(ctx, State.BetaMemory.new(parent_ref))

        ctx =
          ctx
          |> Engine.JoinNode.add_child_ref!(parent_ref, ref)
          |> update_new_node_with_matches_from_above(ref)

        {ctx, ref}

      _ ->
        {ctx, suitable_child_ref}
    end
  end

  @spec left_activate(ctx, ref, partial_activation, Fact.t(), :add | :remove) :: ctx
  def left_activate(ctx, ref, partial_activation, fact, op) do
    partial_activation = [fact | partial_activation]

    ctx
    |> add_or_remove_partial_activation(ref, partial_activation, op)
    |> left_activate_children(ref, partial_activation, op)
  end

  @spec find_child!(state, ref, (mem_data -> boolean)) :: State.JoinNode.ref() | nil
  def find_child!(state, parent_ref, pred) do
    parent = fetch!(state, parent_ref)

    Enum.find(parent.child_refs, fn child_ref ->
      pred.(Engine.JoinNode.fetch!(state, child_ref))
    end)
  end

  @spec add_join_node!(ctx, ref, State.JoinNode.ref()) :: ctx
  def add_join_node!(ctx, bmem_ref, join_node_ref) do
    update!(ctx, bmem_ref, fn mem ->
      %{mem | child_refs: MapSet.put(mem.child_refs, join_node_ref)}
    end)
  end

  @spec update_new_node_with_matches_from_above(ctx, ref) :: ctx
  defp update_new_node_with_matches_from_above(ctx, ref) do
    parent_ref = fetch!(ctx.state, ref).parent_ref
    Engine.JoinNode.update_new_child_node_with_matches_from_above(ctx, parent_ref, ref)
  end

  @spec update!(ctx, ref, (mem_data -> mem_data)) :: ctx
  defp update!(ctx, ref, f) do
    state = ctx.state
    mems = State.RefMap.update!(state.beta_memories, ref, f)
    state = %{state | beta_memories: mems}
    %{ctx | state: state}
  end

  @spec insert(ctx, mem_data) :: {ctx, ref}
  defp insert(ctx, mem_data) do
    state = ctx.state
    {mems, ref} = State.RefMap.insert(state.beta_memories, mem_data)
    state = %{state | beta_memories: mems}
    {%{ctx | state: state}, ref}
  end

  @spec add_or_remove_partial_activation(ctx, ref, partial_activation, :add | :remove) :: ctx
  defp add_or_remove_partial_activation(ctx, ref, partial_activation, :add) do
    update!(ctx, ref, fn mem ->
      %{mem | partial_activations: MapSet.put(mem.partial_activations, partial_activation)}
    end)
  end

  defp add_or_remove_partial_activation(ctx, ref, partial_activation, :remove) do
    update!(ctx, ref, fn mem ->
      %{mem | partial_activations: MapSet.delete(mem.partial_activations, partial_activation)}
    end)
  end

  @spec left_activate_children(ctx, ref, partial_activation, :add | :remove) :: ctx
  defp left_activate_children(ctx, ref, partial_activation, op) do
    # for each child join node of the beta memory, perform a left activation, and return the final ctx
    Enum.reduce(
      fetch!(ctx.state, ref).child_refs,
      ctx,
      fn join_node_ref, ctx ->
        Engine.JoinNode.left_activate(ctx, join_node_ref, partial_activation, op)
      end
    )
  end
end
