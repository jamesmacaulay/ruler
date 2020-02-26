defmodule Ruler.EngineTest do
  use ExUnit.Case

  alias Ruler.{
    Activation,
    Engine,
    Rule
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

    engine =
      Engine.new()
      |> Engine.add_rule(rule)
      |> Engine.add_fact({"user:1", :name, "Alice"})

    expected_activation = %Activation{
      rule_id: :simple_constant_test,
      facts: [{"user:1", :name, "Alice"}],
      bindings: %{:id => "user:1"}
    }

    assert engine.log == [
             {:activation_event, {:activate, expected_activation}},
             {:fact_was_added, {"user:1", :name, "Alice"}},
             {:add_fact_source, {"user:1", :name, "Alice"}, :explicit_assertion},
             {:instruction, {:add_fact, {"user:1", :name, "Alice"}}},
             {:instruction, {:add_rule, rule}}
           ]

    assert engine.state.proposed_activations == MapSet.new([expected_activation])
    assert engine.state.committed_activations == MapSet.new([expected_activation])
  end

  test "add fact, then add matching simple constant test rule" do
    rule = %Rule{
      id: :simple_constant_test,
      conditions: [
        {{:var, :id}, {:const, :name}, {:const, "Alice"}}
      ],
      actions: []
    }

    engine =
      Engine.new()
      |> Engine.add_fact({"user:1", :name, "Alice"})
      |> Engine.add_rule(rule)

    expected_activation = %Activation{
      rule_id: :simple_constant_test,
      facts: [{"user:1", :name, "Alice"}],
      bindings: %{:id => "user:1"}
    }

    assert engine.log == [
             {:activation_event, {:activate, expected_activation}},
             {:instruction, {:add_rule, rule}},
             {:fact_was_added, {"user:1", :name, "Alice"}},
             {:add_fact_source, {"user:1", :name, "Alice"}, :explicit_assertion},
             {:instruction, {:add_fact, {"user:1", :name, "Alice"}}}
           ]

    assert engine.state.proposed_activations == MapSet.new([expected_activation])
    assert engine.state.committed_activations == MapSet.new([expected_activation])
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

    engine =
      Engine.new()
      |> Engine.add_rule(rule)
      |> Engine.add_fact({"user:alice", :follows, "user:bob"})
      |> Engine.add_fact({"user:bob", :name, "Bob"})
      |> Engine.add_fact({"user:alice", :name, "Alice"})
      |> Engine.add_fact({"user:bob", :follows, "user:alice"})

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

    assert engine.log == [
             {:activation_event, {:activate, expected_activation}},
             {:fact_was_added, {"user:bob", :follows, "user:alice"}},
             {:add_fact_source, {"user:bob", :follows, "user:alice"}, :explicit_assertion},
             {:instruction, {:add_fact, {"user:bob", :follows, "user:alice"}}},
             {:fact_was_added, {"user:alice", :name, "Alice"}},
             {:add_fact_source, {"user:alice", :name, "Alice"}, :explicit_assertion},
             {:instruction, {:add_fact, {"user:alice", :name, "Alice"}}},
             {:fact_was_added, {"user:bob", :name, "Bob"}},
             {:add_fact_source, {"user:bob", :name, "Bob"}, :explicit_assertion},
             {:instruction, {:add_fact, {"user:bob", :name, "Bob"}}},
             {:fact_was_added, {"user:alice", :follows, "user:bob"}},
             {:add_fact_source, {"user:alice", :follows, "user:bob"}, :explicit_assertion},
             {:instruction, {:add_fact, {"user:alice", :follows, "user:bob"}}},
             {:instruction, {:add_rule, rule}}
           ]

    assert engine.state.proposed_activations == MapSet.new([expected_activation])
    assert engine.state.committed_activations == MapSet.new([expected_activation])
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

    engine =
      Engine.new()
      |> Engine.add_fact({"user:alice", :follows, "user:bob"})
      |> Engine.add_fact({"user:bob", :name, "Bob"})
      |> Engine.add_fact({"user:alice", :name, "Alice"})
      |> Engine.add_fact({"user:bob", :follows, "user:alice"})
      |> Engine.add_rule(rule)

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

    assert engine.log == [
             {:activation_event, {:activate, expected_activation}},
             {:instruction, {:add_rule, rule}},
             {:fact_was_added, {"user:bob", :follows, "user:alice"}},
             {:add_fact_source, {"user:bob", :follows, "user:alice"}, :explicit_assertion},
             {:instruction, {:add_fact, {"user:bob", :follows, "user:alice"}}},
             {:fact_was_added, {"user:alice", :name, "Alice"}},
             {:add_fact_source, {"user:alice", :name, "Alice"}, :explicit_assertion},
             {:instruction, {:add_fact, {"user:alice", :name, "Alice"}}},
             {:fact_was_added, {"user:bob", :name, "Bob"}},
             {:add_fact_source, {"user:bob", :name, "Bob"}, :explicit_assertion},
             {:instruction, {:add_fact, {"user:bob", :name, "Bob"}}},
             {:fact_was_added, {"user:alice", :follows, "user:bob"}},
             {:add_fact_source, {"user:alice", :follows, "user:bob"}, :explicit_assertion},
             {:instruction, {:add_fact, {"user:alice", :follows, "user:bob"}}}
           ]

    assert engine.state.proposed_activations == MapSet.new([expected_activation])
    assert engine.state.committed_activations == MapSet.new([expected_activation])
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

    engine =
      Engine.new()
      |> Engine.add_fact({"user:alice", :follows, "user:bob"})
      |> Engine.add_fact({"user:bob", :name, "Bob"})
      |> Engine.add_fact({"user:alice", :name, "Alice"})
      |> Engine.add_fact({"user:bob", :follows, "user:alice"})
      |> Engine.add_rule(rule)
      |> Engine.remove_fact({"user:alice", :name, "Alice"})

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

    assert engine.log == [
             {:activation_event, {:deactivate, expected_activation}},
             {:fact_was_removed, {"user:alice", :name, "Alice"}},
             {:remove_fact_source, {"user:alice", :name, "Alice"}, :explicit_assertion},
             {:instruction, {:remove_fact, {"user:alice", :name, "Alice"}}},
             {:activation_event, {:activate, expected_activation}},
             {:instruction, {:add_rule, rule}},
             {:fact_was_added, {"user:bob", :follows, "user:alice"}},
             {:add_fact_source, {"user:bob", :follows, "user:alice"}, :explicit_assertion},
             {:instruction, {:add_fact, {"user:bob", :follows, "user:alice"}}},
             {:fact_was_added, {"user:alice", :name, "Alice"}},
             {:add_fact_source, {"user:alice", :name, "Alice"}, :explicit_assertion},
             {:instruction, {:add_fact, {"user:alice", :name, "Alice"}}},
             {:fact_was_added, {"user:bob", :name, "Bob"}},
             {:add_fact_source, {"user:bob", :name, "Bob"}, :explicit_assertion},
             {:instruction, {:add_fact, {"user:bob", :name, "Bob"}}},
             {:fact_was_added, {"user:alice", :follows, "user:bob"}},
             {:add_fact_source, {"user:alice", :follows, "user:bob"}, :explicit_assertion},
             {:instruction, {:add_fact, {"user:alice", :follows, "user:bob"}}}
           ]

    assert engine.state.proposed_activations == MapSet.new([])
    assert engine.state.committed_activations == MapSet.new([])
  end

  defmodule Effects do
    def echo(engine, activation_event) do
      send(self(), {:echo, engine, activation_event})
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

    engine =
      Engine.new()
      |> Engine.add_rule(rule)
      |> Engine.add_fact({"user:1", :name, "Alice"})

    assert_received({:echo, ^engine, {:activate, ^expected_activation}})

    engine =
      engine
      |> Engine.remove_fact({"user:1", :name, "Alice"})

    assert_received({:echo, ^engine, {:deactivate, ^expected_activation}})
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
        {{:var, :x}, {:const, :descendent_of}, {:const, "eve"}}
      ],
      actions: [
        {:perform_effects, {Ruler.EngineTest.Effects, :echo}}
      ]
    }

    engine =
      Engine.new()
      |> Engine.add_rule(children_are_descendents)
      |> Engine.add_rule(ancestry_is_transitive)
      |> Engine.add_rule(announce_descendents_of_eve)
      |> Engine.add_fact({"alice", :child_of, "beatrice"})

    state = engine.state

    assert MapSet.new(Map.keys(state.facts)) ==
             MapSet.new([
               {"alice", :child_of, "beatrice"},
               {"alice", :descendent_of, "beatrice"}
             ])

    engine = Engine.add_fact(engine, {"beatrice", :descendent_of, "eve"})
    state = engine.state

    assert MapSet.new(Map.keys(state.facts)) ==
             MapSet.new([
               {"alice", :child_of, "beatrice"},
               {"alice", :descendent_of, "beatrice"},
               {"beatrice", :descendent_of, "eve"},
               {"alice", :descendent_of, "eve"}
             ])

    alice_becomes_descendent_of_beatrice = %Activation{
      rule_id: :children_are_descendents,
      facts: [{"alice", :child_of, "beatrice"}],
      bindings: %{:x => "alice", :y => "beatrice"}
    }

    alice_becomes_descendent_of_eve = %Activation{
      rule_id: :ancestry_is_transitive,
      facts: [{"alice", :descendent_of, "beatrice"}, {"beatrice", :descendent_of, "eve"}],
      bindings: %{:x => "alice", :y => "beatrice", :z => "eve"}
    }

    beatrice_announced_as_descendent_of_eve = %Activation{
      rule_id: :announce_descendents_of_eve,
      facts: [{"beatrice", :descendent_of, "eve"}],
      bindings: %{:x => "beatrice"}
    }

    alice_announced_as_descendent_of_eve = %Activation{
      rule_id: :announce_descendents_of_eve,
      facts: [{"alice", :descendent_of, "eve"}],
      bindings: %{:x => "alice"}
    }

    assert_received({:echo, %Engine{}, {:activate, ^beatrice_announced_as_descendent_of_eve}})

    assert_received({:echo, %Engine{}, {:activate, ^alice_announced_as_descendent_of_eve}})

    assert engine.log == [
             {:activation_event, {:activate, alice_announced_as_descendent_of_eve}},
             {:fact_was_added, {"alice", :descendent_of, "eve"}},
             {:add_fact_source, {"alice", :descendent_of, "eve"},
              {:implied_by, alice_becomes_descendent_of_eve}},
             {:activation_event, {:activate, alice_becomes_descendent_of_eve}},
             {:activation_event, {:activate, beatrice_announced_as_descendent_of_eve}},
             {:fact_was_added, {"beatrice", :descendent_of, "eve"}},
             {:add_fact_source, {"beatrice", :descendent_of, "eve"}, :explicit_assertion},
             {:instruction, {:add_fact, {"beatrice", :descendent_of, "eve"}}},
             {:fact_was_added, {"alice", :descendent_of, "beatrice"}},
             {:add_fact_source, {"alice", :descendent_of, "beatrice"},
              {:implied_by, alice_becomes_descendent_of_beatrice}},
             {:activation_event, {:activate, alice_becomes_descendent_of_beatrice}},
             {:fact_was_added, {"alice", :child_of, "beatrice"}},
             {:add_fact_source, {"alice", :child_of, "beatrice"}, :explicit_assertion},
             {:instruction, {:add_fact, {"alice", :child_of, "beatrice"}}},
             {:instruction, {:add_rule, announce_descendents_of_eve}},
             {:instruction, {:add_rule, ancestry_is_transitive}},
             {:instruction, {:add_rule, children_are_descendents}}
           ]
  end
end
