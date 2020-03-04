defmodule Ruler.GraphVizTest do
  use ExUnit.Case
  alias Ruler.{Engine, GraphViz, Rule}
  doctest Ruler.GraphViz

  require Engine.Dsl
  import Engine.Dsl, only: [conditions: 1]

  test "render a network with some facts and a matching complex rule with multiple joins" do
    rule = %Rule{
      id: :mutual_follow_test,
      conditions:
        conditions([
          {alice_id, :name, "Alice"},
          {bob_id, :name, "Bob"},
          {alice_id, :follows, bob_id},
          {bob_id, :follows, alice_id}
        ]),
      actions: []
    }

    engine =
      Engine.new()
      |> Engine.add_facts([
        {"user:alice", :follows, "user:bob"},
        {"user:bob", :name, "Bob"},
        {"user:alice", :name, "Alice"},
        {"user:bob", :follows, "user:alice"}
      ])
      |> Engine.add_rules([rule])

    assert GraphViz.to_dot(engine.state) == """
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
