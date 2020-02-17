defmodule Ruler.GraphVizTest do
  use ExUnit.Case
  alias Ruler.{Engine, GraphViz, Rule, State}
  doctest Ruler.GraphViz

  test "render a network with some facts and a matching complex rule with multiple joins" do
    rule = %Rule{
      id: :mutual_follow_test,
      conditions: [
        {{:var, :alice_id}, {:const, :name}, {:const, "Alice"}},
        {{:var, :bob_id}, {:const, :name}, {:const, "Bob"}},
        {{:var, :alice_id}, {:const, :follows}, {:var, :bob_id}},
        {{:var, :bob_id}, {:const, :follows}, {:var, :alice_id}}
      ],
      actions: []
    }

    state =
      State.new()
      |> Engine.add_fact({"user:alice", :follows, "user:bob"})
      |> Map.get(:state)
      |> Engine.add_fact({"user:bob", :name, "Bob"})
      |> Map.get(:state)
      |> Engine.add_fact({"user:alice", :name, "Alice"})
      |> Map.get(:state)
      |> Engine.add_fact({"user:bob", :follows, "user:alice"})
      |> Map.get(:state)
      |> Engine.add_rule(rule)
      |> Map.get(:state)

    assert GraphViz.to_dot(state) == """
           digraph "Ruler.State" {
             subgraph cluster_0 {
               label="Beta Network";
               "{:beta_memory_ref, 0}"; "{:beta_memory_ref, 1}"; "{:beta_memory_ref, 2}"; "{:beta_memory_ref, 3}"; "{:join_node_ref, 0}"; "{:join_node_ref, 1}"; "{:join_node_ref, 2}"; "{:join_node_ref, 3}"; "{:activation_node_ref, :mutual_follow_test}"
             }
             subgraph cluster_1 {
               label="Alpha Network";
               "{:constant_test_node_ref, 0}"; "{:constant_test_node_ref, 1}"; "{:constant_test_node_ref, 2}"; "{:constant_test_node_ref, 3}"; "{:constant_test_node_ref, 4}"; "{:alpha_memory_ref, 0}"; "{:alpha_memory_ref, 1}"; "{:alpha_memory_ref, 2}"
             }
             "{:beta_memory_ref, 3}" -> "{:join_node_ref, 3}"
             "{:beta_memory_ref, 2}" -> "{:join_node_ref, 2}"
             "{:beta_memory_ref, 1}" -> "{:join_node_ref, 1}"
             "{:beta_memory_ref, 0}" -> "{:join_node_ref, 0}"
             "{:join_node_ref, 3}" -> "{:activation_node_ref, :mutual_follow_test}"
             "{:join_node_ref, 2}" -> "{:beta_memory_ref, 3}"
             "{:join_node_ref, 1}" -> "{:beta_memory_ref, 2}"
             "{:join_node_ref, 0}" -> "{:beta_memory_ref, 1}"
             "{:constant_test_node_ref, 4}" -> "{:alpha_memory_ref, 2}"
             "{:constant_test_node_ref, 3}" -> "{:alpha_memory_ref, 1}"
             "{:constant_test_node_ref, 2}" -> "{:alpha_memory_ref, 0}"
             "{:constant_test_node_ref, 1}" -> "{:constant_test_node_ref, 3}"
             "{:constant_test_node_ref, 1}" -> "{:constant_test_node_ref, 2}"
             "{:constant_test_node_ref, 0}" -> "{:constant_test_node_ref, 4}"
             "{:constant_test_node_ref, 0}" -> "{:constant_test_node_ref, 1}"
             "{:alpha_memory_ref, 2}" -> "{:join_node_ref, 3}"
             "{:alpha_memory_ref, 2}" -> "{:join_node_ref, 2}"
             "{:alpha_memory_ref, 1}" -> "{:join_node_ref, 1}"
             "{:alpha_memory_ref, 0}" -> "{:join_node_ref, 0}"
           }
           """
  end
end