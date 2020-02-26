defmodule Ruler.Engine.BetaMemory do
  alias Ruler.{
    Engine,
    Fact,
    State
  }

  @type state :: State.t()
  @type engine :: Engine.t()
  @type mem_data :: State.BetaMemory.t()
  @type ref :: State.BetaMemory.ref()
  @type partial_activation :: State.BetaMemory.partial_activation()

  @spec fetch!(state, ref) :: mem_data
  def fetch!(state, ref) do
    State.RefMap.fetch!(state.beta_memories, ref)
  end

  @spec build_or_share(engine, State.JoinNode.ref()) :: {engine, ref}
  def build_or_share(engine, parent_ref) do
    suitable_child_ref = Engine.JoinNode.find_beta_memory_child_ref!(engine.state, parent_ref)

    case suitable_child_ref do
      nil ->
        {engine, ref} = insert(engine, State.BetaMemory.new(parent_ref))

        engine =
          engine
          |> Engine.JoinNode.add_child_ref!(parent_ref, ref)
          |> update_new_node_with_matches_from_above(ref)

        {engine, ref}

      _ ->
        {engine, suitable_child_ref}
    end
  end

  @spec left_activate(engine, ref, partial_activation, Fact.t(), :add | :remove) :: engine
  def left_activate(engine, ref, partial_activation, fact, op) do
    partial_activation = [fact | partial_activation]

    engine
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

  @spec add_join_node!(engine, ref, State.JoinNode.ref()) :: engine
  def add_join_node!(engine, bmem_ref, join_node_ref) do
    update!(engine, bmem_ref, fn mem ->
      %{mem | child_refs: MapSet.put(mem.child_refs, join_node_ref)}
    end)
  end

  @spec update_new_node_with_matches_from_above(engine, ref) :: engine
  defp update_new_node_with_matches_from_above(engine, ref) do
    parent_ref = fetch!(engine.state, ref).parent_ref
    Engine.JoinNode.update_new_child_node_with_matches_from_above(engine, parent_ref, ref)
  end

  @spec update!(engine, ref, (mem_data -> mem_data)) :: engine
  defp update!(engine, ref, f) do
    state = engine.state
    mems = State.RefMap.update!(state.beta_memories, ref, f)
    state = %{state | beta_memories: mems}
    %{engine | state: state}
  end

  @spec insert(engine, mem_data) :: {engine, ref}
  defp insert(engine, mem_data) do
    state = engine.state
    {mems, ref} = State.RefMap.insert(state.beta_memories, mem_data)
    state = %{state | beta_memories: mems}
    {%{engine | state: state}, ref}
  end

  @spec add_or_remove_partial_activation(engine, ref, partial_activation, :add | :remove) ::
          engine
  defp add_or_remove_partial_activation(engine, ref, partial_activation, :add) do
    update!(engine, ref, fn mem ->
      %{mem | partial_activations: MapSet.put(mem.partial_activations, partial_activation)}
    end)
  end

  defp add_or_remove_partial_activation(engine, ref, partial_activation, :remove) do
    update!(engine, ref, fn mem ->
      %{mem | partial_activations: MapSet.delete(mem.partial_activations, partial_activation)}
    end)
  end

  @spec left_activate_children(engine, ref, partial_activation, :add | :remove) :: engine
  defp left_activate_children(engine, ref, partial_activation, op) do
    # for each child join node of the beta memory, perform a left activation, and return the final engine
    Enum.reduce(
      fetch!(engine.state, ref).child_refs,
      engine,
      fn join_node_ref, engine ->
        Engine.JoinNode.left_activate(engine, join_node_ref, partial_activation, op)
      end
    )
  end
end
