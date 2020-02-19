defmodule Ruler.EngineTest do
  use ExUnit.Case

  alias Ruler.{
    Activation,
    Engine,
    Rule,
    State
  }

  doctest Ruler.Engine

  test "add simple constant test rule, then add matching fact" do
    rule = %Rule{
      id: :simple_constant_test,
      conditions: [
        {{:var, :id}, {:const, :name}, {:const, "Alice"}}
      ],
      actions: []
    }

    ctx =
      State.new()
      |> Engine.add_rule(rule)
      |> Map.get(:state)
      |> Engine.add_fact({"user:1", :name, "Alice"})

    activation_node = Engine.ActivationNode.fetch_with_rule_id!(ctx.state, :simple_constant_test)

    expected_activation = %Activation{
      rule_id: :simple_constant_test,
      facts: [{"user:1", :name, "Alice"}],
      bindings: %{:id => "user:1"}
    }

    assert ctx.activation_events == [{:activate, expected_activation}]
    assert activation_node.activations == MapSet.new([expected_activation])
  end

  test "add fact, then add matching simple constant test rule" do
    rule = %Rule{
      id: :simple_constant_test,
      conditions: [
        {{:var, :id}, {:const, :name}, {:const, "Alice"}}
      ],
      actions: []
    }

    ctx =
      State.new()
      |> Engine.add_fact({"user:1", :name, "Alice"})
      |> Map.get(:state)
      |> Engine.add_rule(rule)

    activation_node = Engine.ActivationNode.fetch_with_rule_id!(ctx.state, :simple_constant_test)

    expected_activation = %Activation{
      rule_id: :simple_constant_test,
      facts: [{"user:1", :name, "Alice"}],
      bindings: %{:id => "user:1"}
    }

    assert ctx.activation_events == [{:activate, expected_activation}]
    assert activation_node.activations == MapSet.new([expected_activation])
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

    ctx =
      State.new()
      |> Engine.add_rule(rule)
      |> Map.get(:state)
      |> Engine.add_fact({"user:alice", :follows, "user:bob"})
      |> Map.get(:state)
      |> Engine.add_fact({"user:bob", :name, "Bob"})
      |> Map.get(:state)
      |> Engine.add_fact({"user:alice", :name, "Alice"})
      |> Map.get(:state)
      |> Engine.add_fact({"user:bob", :follows, "user:alice"})

    activation_node = Engine.ActivationNode.fetch_with_rule_id!(ctx.state, :mutual_follow_test)

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

    assert ctx.activation_events == [{:activate, expected_activation}]
    assert activation_node.activations == MapSet.new([expected_activation])
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

    ctx =
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

    activation_node = Engine.ActivationNode.fetch_with_rule_id!(ctx.state, :mutual_follow_test)

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

    assert ctx.activation_events == [{:activate, expected_activation}]
    assert activation_node.activations == MapSet.new([expected_activation])
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

    ctx =
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
      |> Engine.remove_fact({"user:alice", :name, "Alice"})

    activation_node = Engine.ActivationNode.fetch_with_rule_id!(ctx.state, :mutual_follow_test)

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

    assert ctx.activation_events == [{:deactivate, expected_removed_activation}]
    assert activation_node.activations == MapSet.new()
  end

  defmodule Effects do
    def echo(ctx, activation_event) do
      send(self(), {:echo, ctx, activation_event})
    end
  end

  test "perform_effects action" do
    rule = %Rule{
      id: :send_echo_when_alice_appears,
      conditions: [
        {{:var, :id}, {:const, :name}, {:const, "Alice"}}
      ],
      actions: [
        {:perform_effects, {Ruler.EngineTest.Effects, :echo}}
      ]
    }

    expected_activation = %Activation{
      rule_id: :send_echo_when_alice_appears,
      facts: [{"user:1", :name, "Alice"}],
      bindings: %{:id => "user:1"}
    }

    ctx =
      State.new()
      |> Engine.add_rule(rule)
      |> Map.get(:state)
      |> Engine.add_fact({"user:1", :name, "Alice"})

    assert_received({:echo, ^ctx, {:activate, ^expected_activation}})

    ctx =
      ctx.state
      |> Engine.remove_fact({"user:1", :name, "Alice"})

    assert_received({:echo, ^ctx, {:deactivate, ^expected_activation}})
  end

  test "implications" do
    children_are_descendents = %Rule{
      id: :children_are_descendents,
      conditions: [
        {{:var, :x}, {:const, :child_of}, {:var, :y}}
      ],
      actions: [
        {:imply, {{:var, :x}, {:const, :descendent_of}, {:var, :y}}}
      ]
    }

    ancestry_is_transitive = %Rule{
      id: :ancestry_is_transitive,
      conditions: [
        {{:var, :x}, {:const, :descendent_of}, {:var, :y}},
        {{:var, :y}, {:const, :descendent_of}, {:var, :z}}
      ],
      actions: [
        {:imply, {{:var, :x}, {:const, :descendent_of}, {:var, :z}}}
      ]
    }

    announce_descendents_of_eve = %Rule{
      id: :announce_descendents_of_eve,
      conditions: [
        {{:var, :x}, {:const, :descendent_of}, {:const, :eve}}
      ],
      actions: [
        {:perform_effects, {Ruler.EngineTest.Effects, :echo}}
      ]
    }

    state =
      State.new()
      |> Engine.add_rule(children_are_descendents)
      |> Map.get(:state)
      |> Engine.add_rule(ancestry_is_transitive)
      |> Map.get(:state)
      |> Engine.add_rule(announce_descendents_of_eve)
      |> Map.get(:state)

    state = Engine.add_fact(state, {"alice", :child_of, "beatrice"}).state

    assert MapSet.new(Map.keys(state.facts)) ==
             MapSet.new([
               {"alice", :child_of, "beatrice"},
               {"alice", :descendent_of, "beatrice"}
             ])

    ctx = Engine.add_fact(state, {"beatrice", :descendent_of, "eve"})
    state = ctx.state

    assert MapSet.new(Map.keys(state.facts)) ==
             MapSet.new([
               {"alice", :child_of, "beatrice"},
               {"alice", :descendent_of, "beatrice"},
               {"beatrice", :descendent_of, "eve"},
               {"alice", :descendent_of, "eve"}
             ])

    assert_received(
      {:echo, ^ctx,
       {:activate,
        %Activation{
          rule_id: :announce_descendents_of_eve,
          facts: [{"beatrice", :descendent_of, "eve"}],
          bindings: %{:x => "beatrice"}
        }}}
    )

    assert_received(
      {:echo, ^ctx,
       {:activate,
        %Activation{
          rule_id: :announce_descendents_of_eve,
          facts: [{"alice", :descendent_of, "eve"}],
          bindings: %{:x => "alice"}
        }}}
    )
  end
end
