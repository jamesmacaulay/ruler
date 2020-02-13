defmodule Ruler.Engine.BetaMemory do
  alias Ruler.{
    Engine,
    Fact,
    State
  }

  @type state :: State.t()
  @type mem_data :: State.BetaMemory.t()
  @type ref :: State.BetaMemory.ref()
  @type partial_activation :: State.BetaMemory.partial_activation()

  @spec fetch!(state, ref) :: mem_data
  def fetch!(state, ref) do
    State.RefMap.fetch!(state.beta_memories, ref)
  end

  @spec build_or_share(state, State.JoinNode.ref()) :: {state, ref}
  def build_or_share(state, parent_ref) do
    suitable_child_ref = Engine.JoinNode.find_beta_memory_child_ref!(state, parent_ref)

    case suitable_child_ref do
      nil ->
        {state, ref} = insert(state, State.BetaMemory.new(parent_ref))

        state =
          state
          |> Engine.JoinNode.add_child_ref!(parent_ref, ref)
          |> update_new_node_with_matches_from_above(ref)

        {state, ref}

      _ ->
        {state, suitable_child_ref}
    end
  end

  @spec left_activate(state, ref, partial_activation, Fact.t(), :add | :remove) :: state
  def left_activate(state, ref, partial_activation, fact, op) do
    partial_activation = [fact | partial_activation]

    state
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

  @spec add_join_node!(state, ref, State.JoinNode.ref()) :: state
  def add_join_node!(state, bmem_ref, join_node_ref) do
    update!(state, bmem_ref, fn mem ->
      %{mem | child_refs: MapSet.put(mem.child_refs, join_node_ref)}
    end)
  end

  @spec update_new_node_with_matches_from_above(state, ref) :: state
  defp update_new_node_with_matches_from_above(state, ref) do
    parent_ref = fetch!(state, ref).parent_ref
    Engine.JoinNode.update_new_child_node_with_matches_from_above(state, parent_ref, ref)
  end

  @spec update!(state, ref, (mem_data -> mem_data)) :: state
  defp update!(state, ref, f) do
    mems = State.RefMap.update!(state.beta_memories, ref, f)
    %{state | beta_memories: mems}
  end

  @spec insert(state, mem_data) :: {state, ref}
  defp insert(state, mem_data) do
    {mems, ref} = State.RefMap.insert(state.beta_memories, mem_data)
    {%{state | beta_memories: mems}, ref}
  end

  @spec add_or_remove_partial_activation(state, ref, partial_activation, :add | :remove) :: state
  defp add_or_remove_partial_activation(state, ref, partial_activation, :add) do
    update!(state, ref, fn mem ->
      %{mem | partial_activations: MapSet.put(mem.partial_activations, partial_activation)}
    end)
  end

  defp add_or_remove_partial_activation(state, ref, partial_activation, :remove) do
    update!(state, ref, fn mem ->
      %{mem | partial_activations: MapSet.delete(mem.partial_activations, partial_activation)}
    end)
  end

  @spec left_activate_children(state, ref, partial_activation, :add | :remove) :: state
  defp left_activate_children(state, ref, partial_activation, op) do
    # for each child join node of the beta memory, perform a left activation, and return the final state
    Enum.reduce(
      fetch!(state, ref).child_refs,
      state,
      fn join_node_ref, state ->
        Engine.JoinNode.left_activate(state, join_node_ref, partial_activation, op)
      end
    )
  end
end
