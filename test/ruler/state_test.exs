defmodule Ruler.StateTest do
  use ExUnit.Case
  alias Ruler.{GraphViz, Rule, State}
  doctest Ruler.State

  test "add_fact, remove_fact, has_fact? updates and reads from state" do
    fact = {:alice, :follows, :bob}
    state = State.new()

    assert !State.has_fact?(state, fact)

    state = State.add_fact(state, fact)

    assert State.has_fact?(state, fact)

    state = State.remove_fact(state, fact)

    assert !State.has_fact?(state, fact)
  end

  test "add_rule, has_rule? updates and reads from state" do
    rule = %Rule{
      id: :mutual_follow,
      conditions: [
        {{:var, :x}, {:const, :follows}, {:var, :y}},
        {{:var, :y}, {:const, :follows}, {:var, :x}}
      ],
      actions: []
    }

    state = State.new()

    assert !State.has_rule?(state, :mutual_follow)

    state = State.add_rule(state, rule)

    assert State.has_rule?(state, :mutual_follow)
  end

  test "add simple constant test rule, then add matching fact" do
    state = State.new()

    rule = %Rule{
      id: :simple_constant_test,
      conditions: [
        {{:var, :id}, {:const, :name}, {:const, "Alice"}}
      ],
      actions: []
    }

    fact = {"user:1", :name, "Alice"}

    state = State.add_rule(state, rule)

    state = State.add_fact(state, fact)

    [{:add_activation, activation}] = state.latest_activation_events

    assert activation.rule_id == :simple_constant_test
    assert activation.facts == [{"user:1", :name, "Alice"}]
    assert activation.bindings == %{:id => "user:1"}
  end

  test "add fact, then add matching simple constant test rule" do
    state = State.new()

    rule = %Rule{
      id: :simple_constant_test,
      conditions: [
        {{:var, :id}, {:const, :name}, {:const, "Alice"}}
      ],
      actions: []
    }

    fact = {"user:1", :name, "Alice"}

    state = State.add_fact(state, fact)

    state = State.add_rule(state, rule)

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
      |> State.add_rule(rule)
      |> State.add_fact({"user:alice", :follows, "user:bob"})
      |> State.add_fact({"user:bob", :name, "Bob"})
      |> State.add_fact({"user:alice", :name, "Alice"})
      |> State.add_fact({"user:bob", :follows, "user:alice"})

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
      |> State.add_fact({"user:alice", :follows, "user:bob"})
      |> State.add_fact({"user:bob", :name, "Bob"})
      |> State.add_fact({"user:alice", :name, "Alice"})
      |> State.add_fact({"user:bob", :follows, "user:alice"})
      |> State.add_rule(rule)

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
end
