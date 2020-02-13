defmodule Ruler.EngineTest do
  use ExUnit.Case
  alias Ruler.{Engine, Rule, State}
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

    [{:add_activation, activation}] = state.latest_activation_events

    assert activation.rule_id == :simple_constant_test
    assert activation.facts == [{"user:1", :name, "Alice"}]
    assert activation.bindings == %{:id => "user:1"}
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

    [{:add_activation, activation}] = state.latest_activation_events

    assert activation.rule_id == :simple_constant_test
    assert activation.facts == [{"user:1", :name, "Alice"}]
    assert activation.bindings == %{:id => "user:1"}
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

    [{:add_activation, activation}] = state.latest_activation_events

    assert activation.rule_id == :mutual_follow_test

    assert activation.facts == [
             {"user:alice", :name, "Alice"},
             {"user:bob", :name, "Bob"},
             {"user:alice", :follows, "user:bob"},
             {"user:bob", :follows, "user:alice"}
           ]

    assert activation.bindings == %{alice_id: "user:alice", bob_id: "user:bob"}
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

    [{:add_activation, activation}] = state.latest_activation_events

    assert activation.rule_id == :mutual_follow_test

    assert activation.facts == [
             {"user:alice", :name, "Alice"},
             {"user:bob", :name, "Bob"},
             {"user:alice", :follows, "user:bob"},
             {"user:bob", :follows, "user:alice"}
           ]

    assert activation.bindings == %{alice_id: "user:alice", bob_id: "user:bob"}
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

    [{:remove_activation, activation} | _] = state.latest_activation_events

    assert activation.rule_id == :mutual_follow_test

    assert activation.facts == [
             {"user:alice", :name, "Alice"},
             {"user:bob", :name, "Bob"},
             {"user:alice", :follows, "user:bob"},
             {"user:bob", :follows, "user:alice"}
           ]

    assert activation.bindings == %{alice_id: "user:alice", bob_id: "user:bob"}
  end
end
