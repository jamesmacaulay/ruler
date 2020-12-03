defmodule Ruler.Engine.NegativeNode do
  alias Ruler.{
    Engine,
    Fact,
    State
  }

  @type state :: State.t()
  @type engine :: Engine.t()
  @type node_data :: State.NegativeNode.t()
  @type ref :: State.NegativeNode.ref()
  @type child_ref :: State.NegativeNode.child_ref()
  @type partial_activation :: State.NegativeNode.partial_activation()

  @spec fetch!(state, ref) :: node_data
  def fetch!(state, ref) do
    State.RefMap.fetch!(state.negative_nodes, ref)
  end

  @spec left_activate(engine, ref, partial_activation, Fact.t() | nil, :add | :remove) :: engine
  def left_activate(engine, ref, partial_activation, fact, op) do
    partial_activation = [fact | partial_activation]

    engine
    |> add_or_remove_partial_activation(ref, partial_activation, op)
    |> compute_join_results(ref, partial_activation, op)
    |> activate_children(ref, partial_activation, op)
  end

  @spec right_activate(engine, ref, Fact.t(), :add | :remove) :: engine
  def right_activate(engine, ref, fact, op) do
    state = engine.state
    node = fetch!(state, ref)

    Enum.reduce(node.partial_activations, engine, fn partial_activation, engine ->
      compare_and_activate_children(engine, node, partial_activation, fact, op)
    end)
  end

  @spec compare_and_activate_children(
          engine,
          node_data,
          partial_activation,
          Fact.t(),
          :add | :remove
        ) ::
          engine
  defp compare_and_activate_children(engine, node, partial_activation, fact, op) do
    if State.JoinNode.perform_join_comparisons(node.comparisons, partial_activation, fact) do
      Enum.reduce(node.child_refs, engine, fn child_ref, engine ->
        Engine.JoinNode.left_activate_child(engine, child_ref, partial_activation, fact, op)
      end)
    else
      engine
    end
  end

  @spec add_or_remove_partial_activation(engine, ref, partial_activation, :add | :remove) ::
          engine
  defp add_or_remove_partial_activation(engine, ref, partial_activation, :add) do
    update!(engine, ref, fn node ->
      %{node | partial_activations: MapSet.put(node.partial_activations, partial_activation)}
    end)
  end

  defp add_or_remove_partial_activation(engine, ref, partial_activation, :remove) do
    update!(engine, ref, fn node ->
      %{node | partial_activations: MapSet.delete(node.partial_activations, partial_activation)}
    end)
  end

  @spec compute_join_results(engine, ref, partial_activation, :add | :remove) :: engine
  defp compute_join_results(engine, ref, partial_activation, op) do
    state = engine.state
    node = fetch!(state, ref)
    alpha_memory = Engine.AlphaMemory.fetch!(state, node.alpha_memory_ref)

    Enum.reduce(alpha_memory.facts, engine, fn fact, engine ->
      if State.JoinNode.perform_join_comparisons(node.comparisons, partial_activation, fact) do
        case op do
          :add ->
            update!(engine, ref, fn node ->
              %{node | join_results: MapSet.put(node.join_results, fact)}
            end)

          :remove ->
            update!(engine, ref, fn node ->
              %{
                node
                | join_results:
                    node.join_results
                    |> Enum.reject(fn join_result ->
                      join_result == partial_activation
                    end)
              }
            end)
        end
      else
        engine
      end
    end)
  end

  @spec activate_children(engine, ref, partial_activation, :add | :remove) :: engine
  defp activate_children(engine, ref, partial_activation, op) do
    state = engine.state
    node = fetch!(state, ref)

    if MapSet.size(node.join_results) == 0 do
      Enum.reduce(node.child_refs, engine, fn child_ref, engine ->
        Engine.JoinNode.left_activate_child(engine, child_ref, partial_activation, nil, op)
      end)
    else
      engine
    end
  end

  @spec update!(engine, ref, (node_data -> node_data)) :: engine
  defp update!(engine, ref, f) do
    state = engine.state
    nodes = State.RefMap.update!(state.negative_nodes, ref, f)
    state = %{state | negative_nodes: nodes}
    %{engine | state: state}
  end

  @spec insert(engine, node_data) :: {engine, ref}
  defp insert(engine, node_data) do
    state = engine.state
    {nodes, ref} = State.RefMap.insert(state.negative_nodes, node_data)
    state = %{state | negative_nodes: nodes}
    {%{engine | state: state}, ref}
  end

  @spec update_new_child_node_with_matches_from_above(engine, ref, child_ref) :: engine
  def update_new_child_node_with_matches_from_above(engine, ref, child_ref) do
    state = engine.state
    node = fetch!(state, ref)
    amem = Engine.AlphaMemory.fetch!(state, node.alpha_memory_ref)
    saved_child_refs = node.child_refs

    engine = update!(engine, ref, fn node -> %{node | child_refs: [child_ref]} end)

    engine =
      Enum.reduce(amem.facts, engine, fn fact, engine ->
        right_activate(engine, ref, fact, :add)
      end)

    update!(engine, ref, fn node -> %{node | child_refs: saved_child_refs} end)
  end

  @spec add_child_ref!(engine, ref, child_ref) :: engine
  def add_child_ref!(engine, ref, child_ref) do
    update!(engine, ref, fn node ->
      %{node | child_refs: [child_ref | node.child_refs]}
    end)
  end

  @spec build_or_share(engine, State.BetaMemory.ref(), State.AlphaMemory.ref(), [Comparison.t()]) ::
          {engine, ref}
  def build_or_share(engine, parent_ref, amem_ref, comparisons) do
    suitable_child_ref =
      case parent_ref do
        {:beta_memory_ref, _} ->
          Engine.BetaMemory.find_negative_node_child!(engine.state, parent_ref, fn child ->
            child.alpha_memory_ref == amem_ref && child.comparisons == comparisons
          end)

        {:join_node_ref, _} ->
          Engine.JoinNode.find_negative_node_child!(engine.state, parent_ref, fn child ->
            child.alpha_memory_ref == amem_ref && child.comparisons == comparisons
          end)
      end

    case suitable_child_ref do
      nil ->
        {engine, ref} =
          insert(engine, %State.NegativeNode{
            parent_ref: parent_ref,
            child_refs: [],
            partial_activations: MapSet.new(),
            alpha_memory_ref: amem_ref,
            comparisons: comparisons,
            join_results: MapSet.new()
          })

        engine =
          engine
          |> Engine.AlphaMemory.add_beta_node!(amem_ref, ref)
          |> Engine.BetaMemory.add_child_node!(parent_ref, ref)

        {engine, ref}

      _ ->
        {engine, suitable_child_ref}
    end
  end
end
