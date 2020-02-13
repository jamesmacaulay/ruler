defmodule Ruler.EngineTest do
  use ExUnit.Case
  alias Ruler.{Activation, Engine, Rule, State}
  doctest Ruler.Engine

  test "add simple constant test rule, then add matching fact" do
    rule = %Rule{
      id: :simple_constant_test,
      conditions: [
        {{:var, :id}, {:const, :name}, {:const, "Alice"}}
      ],
      actions: []
    }

    state =
      State.new()
      |> Engine.add_rule(rule)
      |> Engine.add_fact({"user:1", :name, "Alice"})

    activation_node = Engine.ActivationNode.fetch_with_rule_id!(state, :simple_constant_test)

    expected_activation = %Activation{
      rule_id: :simple_constant_test,
      facts: [{"user:1", :name, "Alice"}],
      bindings: %{:id => "user:1"}
    }

    assert {:add_activation, expected_activation} == Enum.at(state.latest_activation_events, 0)
    assert MapSet.new([expected_activation]) == activation_node.activations
  end

  test "add fact, then add matching simple constant test rule" do
    rule = %Rule{
      id: :simple_constant_test,
      conditions: [
        {{:var, :id}, {:const, :name}, {:const, "Alice"}}
      ],
      actions: []
    }

    state =
      State.new()
      |> Engine.add_fact({"user:1", :name, "Alice"})
      |> Engine.add_rule(rule)

    activation_node = Engine.ActivationNode.fetch_with_rule_id!(state, :simple_constant_test)

    expected_activation = %Activation{
      rule_id: :simple_constant_test,
      facts: [{"user:1", :name, "Alice"}],
      bindings: %{:id => "user:1"}
    }

    assert {:add_activation, expected_activation} == Enum.at(state.latest_activation_events, 0)
    assert MapSet.new([expected_activation]) == activation_node.activations
  end

  test "add complex rule with multiple joins, then add facts to match" do
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
      |> Engine.add_rule(rule)
      |> Engine.add_fact({"user:alice", :follows, "user:bob"})
      |> Engine.add_fact({"user:bob", :name, "Bob"})
      |> Engine.add_fact({"user:alice", :name, "Alice"})
      |> Engine.add_fact({"user:bob", :follows, "user:alice"})

    activation_node = Engine.ActivationNode.fetch_with_rule_id!(state, :mutual_follow_test)

    expected_activation = %Activation{
      rule_id: :mutual_follow_test,
      facts: [
        {"user:alice", :name, "Alice"},
        {"user:bob", :name, "Bob"},
        {"user:alice", :follows, "user:bob"},
        {"user:bob", :follows, "user:alice"}
      ],
      bindings: %{alice_id: "user:alice", bob_id: "user:bob"}
    }

    assert {:add_activation, expected_activation} == Enum.at(state.latest_activation_events, 0)
    assert MapSet.new([expected_activation]) == activation_node.activations
  end

  test "add facts, then add matching complex rule with multiple joins" do
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
      |> Engine.add_fact({"user:bob", :name, "Bob"})
      |> Engine.add_fact({"user:alice", :name, "Alice"})
      |> Engine.add_fact({"user:bob", :follows, "user:alice"})
      |> Engine.add_rule(rule)

    activation_node = Engine.ActivationNode.fetch_with_rule_id!(state, :mutual_follow_test)

    expected_activation = %Activation{
      rule_id: :mutual_follow_test,
      facts: [
        {"user:alice", :name, "Alice"},
        {"user:bob", :name, "Bob"},
        {"user:alice", :follows, "user:bob"},
        {"user:bob", :follows, "user:alice"}
      ],
      bindings: %{alice_id: "user:alice", bob_id: "user:bob"}
    }

    assert {:add_activation, expected_activation} == Enum.at(state.latest_activation_events, 0)
    assert MapSet.new([expected_activation]) == activation_node.activations
  end

  test "add facts, then add matching complex rule with multiple joins, then remove one of the facts" do
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
      |> Engine.add_fact({"user:bob", :name, "Bob"})
      |> Engine.add_fact({"user:alice", :name, "Alice"})
      |> Engine.add_fact({"user:bob", :follows, "user:alice"})
      |> Engine.add_rule(rule)
      |> Engine.remove_fact({"user:alice", :name, "Alice"})

    activation_node = Engine.ActivationNode.fetch_with_rule_id!(state, :mutual_follow_test)

    expected_removed_activation = %Activation{
      rule_id: :mutual_follow_test,
      facts: [
        {"user:alice", :name, "Alice"},
        {"user:bob", :name, "Bob"},
        {"user:alice", :follows, "user:bob"},
        {"user:bob", :follows, "user:alice"}
      ],
      bindings: %{alice_id: "user:alice", bob_id: "user:bob"}
    }

    assert {:remove_activation, expected_removed_activation} ==
             Enum.at(state.latest_activation_events, 0)

    assert MapSet.new() == activation_node.activations
  end
end
