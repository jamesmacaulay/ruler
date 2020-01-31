defmodule Ruler.GraphViz do
  alias Ruler.{
    State
  }

  @spec to_dot(State.t()) :: String.t()
  def to_dot(state) do
    beta_memory_refs =
      State.RefMap.keys(state.beta_memories)
      |> Enum.map(fn k -> {:beta_memory_ref, k} end)

    join_node_refs =
      State.RefMap.keys(state.join_nodes)
      |> Enum.map(fn k -> {:join_node_ref, k} end)

    activation_node_refs =
      State.RefMap.keys(state.activation_nodes)
      |> Enum.map(fn k -> {:activation_node_ref, k} end)

    beta_nodes_declaration =
      Enum.concat([beta_memory_refs, join_node_refs, activation_node_refs])
      |> Enum.map(fn ref -> ref_to_id(ref) end)
      |> Enum.join("; ")

    constant_test_node_refs =
      State.RefMap.keys(state.constant_test_nodes)
      |> Enum.map(fn k -> {:constant_test_node_ref, k} end)

    alpha_memory_refs =
      State.RefMap.keys(state.alpha_memories)
      |> Enum.map(fn k -> {:alpha_memory_ref, k} end)

    alpha_nodes_declaration =
      Enum.concat([constant_test_node_refs, alpha_memory_refs])
      |> Enum.map(fn ref -> ref_to_id(ref) end)
      |> Enum.join("; ")

    beta_memory_edges =
      Enum.reduce(beta_memory_refs, [], fn ref = {:beta_memory_ref, _}, result ->
        beta_memory = State.RefMap.fetch!(state.beta_memories, ref)

        beta_memory.children
        |> Enum.map(fn child_ref -> {ref, child_ref} end)
        |> Enum.concat(result)
      end)

    join_node_edges =
      Enum.reduce(join_node_refs, [], fn ref = {:join_node_ref, _}, result ->
        join_node = State.RefMap.fetch!(state.join_nodes, ref)

        join_node.children
        |> Enum.map(fn child_ref -> {ref, child_ref} end)
        |> Enum.concat(result)
      end)

    constant_test_node_edges =
      Enum.reduce(constant_test_node_refs, [], fn ref = {:constant_test_node_ref, _}, result ->
        constant_test_node = State.RefMap.fetch!(state.constant_test_nodes, ref)

        children =
          if constant_test_node.alpha_memory == nil do
            constant_test_node.children
          else
            [constant_test_node.alpha_memory | constant_test_node.children]
          end

        children
        |> Enum.map(fn child_ref -> {ref, child_ref} end)
        |> Enum.concat(result)
      end)

    alpha_memory_edges =
      Enum.reduce(alpha_memory_refs, [], fn ref = {:alpha_memory_ref, _}, result ->
        alpha_memory = State.RefMap.fetch!(state.alpha_memories, ref)

        alpha_memory.join_nodes
        |> Enum.map(fn child_ref -> {ref, child_ref} end)
        |> Enum.concat(result)
      end)

    edges_declaration =
      Enum.concat([
        beta_memory_edges,
        join_node_edges,
        constant_test_node_edges,
        alpha_memory_edges
      ])
      |> Enum.map(fn {parent_ref, child_ref} ->
        "#{ref_to_id(parent_ref)} -> #{ref_to_id(child_ref)}"
      end)
      |> Enum.join("\n  ")

    """
    digraph "Ruler.State" {
      subgraph cluster_0 {
        label="Beta Network";
        #{beta_nodes_declaration}
      }
      subgraph cluster_1 {
        label="Alpha Network";
        #{alpha_nodes_declaration}
      }
      #{edges_declaration}
    }
    """
  end

  @spec ref_to_id({atom(), non_neg_integer()}) :: String.t()
  defp ref_to_id(ref) do
    inspect(inspect(ref))
  end
end
