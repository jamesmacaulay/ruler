defmodule Ruler.EngineTest do
  use ExUnit.Case

  alias Ruler.{
    Activation,
    Engine
  }

  require Engine.Dsl
  import Engine.Dsl, only: [rule: 2, clauses: 1, imply: 1, query: 2]

  doctest Ruler.Engine

  test "add simple constant test rule, then add matching fact" do
    rule =
      rule :simple_constant_test do
        {id, :name, "Alice"} -> []
      end

    engine =
      Engine.new()
      |> Engine.add_rules([rule])
      |> Engine.add_facts([{"user:1", :name, "Alice"}])

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
    rule =
      rule :simple_constant_test do
        {id, :name, "Alice"} -> []
      end

    engine =
      Engine.new()
      |> Engine.add_facts([{"user:1", :name, "Alice"}])
      |> Engine.add_rules([rule])

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
    rule =
      rule :mutual_follow_test do
        [
          {alice_id, :name, "Alice"},
          {bob_id, :name, "Bob"},
          {alice_id, :follows, bob_id},
          {bob_id, :follows, alice_id}
        ] ->
          []
      end

    engine =
      Engine.new()
      |> Engine.add_rules([rule])
      |> Engine.add_facts([
        {"user:alice", :follows, "user:bob"},
        {"user:bob", :name, "Bob"},
        {"user:alice", :name, "Alice"},
        {"user:bob", :follows, "user:alice"}
      ])

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
    rule =
      rule :mutual_follow_test do
        [
          {alice_id, :name, "Alice"},
          {bob_id, :name, "Bob"},
          {alice_id, :follows, bob_id},
          {bob_id, :follows, alice_id}
        ] ->
          []
      end

    engine =
      Engine.new()
      |> Engine.add_facts([
        {"user:alice", :follows, "user:bob"},
        {"user:bob", :name, "Bob"},
        {"user:alice", :name, "Alice"},
        {"user:bob", :follows, "user:alice"}
      ])
      |> Engine.add_rules([rule])

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
    rule =
      rule :mutual_follow_test do
        [
          {alice_id, :name, "Alice"},
          {bob_id, :name, "Bob"},
          {alice_id, :follows, bob_id},
          {bob_id, :follows, alice_id}
        ] ->
          []
      end

    engine =
      Engine.new()
      |> Engine.add_facts([
        {"user:alice", :follows, "user:bob"},
        {"user:bob", :name, "Bob"},
        {"user:alice", :name, "Alice"},
        {"user:bob", :follows, "user:alice"}
      ])
      |> Engine.add_rules([rule])
      |> Engine.remove_facts([{"user:alice", :name, "Alice"}])

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
    rule =
      rule :send_echo_when_alice_appears do
        {id, :name, "Alice"} ->
          [{:perform_effects, {Ruler.EngineTest.Effects, :echo}}]
      end

    expected_activation = %Activation{
      rule_id: :send_echo_when_alice_appears,
      facts: [{"user:1", :name, "Alice"}],
      bindings: %{:id => "user:1"}
    }

    engine =
      Engine.new()
      |> Engine.add_rules([rule])
      |> Engine.add_facts([{"user:1", :name, "Alice"}])

    assert_received({:echo, ^engine, {:activate, ^expected_activation}})

    engine =
      engine
      |> Engine.remove_facts([{"user:1", :name, "Alice"}])

    assert_received({:echo, ^engine, {:deactivate, ^expected_activation}})
  end

  test "implications" do
    children_are_descendents =
      rule :children_are_descendents do
        {x, :child_of, y} ->
          [
            imply({x, :descendent_of, y})
          ]
      end

    ancestry_is_transitive =
      rule :ancestry_is_transitive do
        [
          {x, :descendent_of, y},
          {y, :descendent_of, z}
        ] ->
          [
            imply({x, :descendent_of, z})
          ]
      end

    announce_descendents_of_eve =
      rule :announce_descendents_of_eve do
        {x, :descendent_of, "eve"} ->
          [
            {:perform_effects, {Ruler.EngineTest.Effects, :echo}}
          ]
      end

    engine =
      Engine.new()
      |> Engine.add_rules([
        children_are_descendents,
        ancestry_is_transitive,
        announce_descendents_of_eve
      ])
      |> Engine.add_facts([{"alice", :child_of, "beatrice"}])

    state = engine.state

    assert MapSet.new(Map.keys(state.facts)) ==
             MapSet.new([
               {"alice", :child_of, "beatrice"},
               {"alice", :descendent_of, "beatrice"}
             ])

    engine = Engine.add_facts(engine, [{"beatrice", :descendent_of, "eve"}])
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

  test "query after the fact" do
    rule =
      rule :mutual_follow_test do
        [
          {alice_id, :name, "Alice"},
          {bob_id, :name, "Bob"},
          {alice_id, :follows, bob_id},
          {bob_id, :follows, alice_id}
        ] ->
          []
      end

    engine =
      Engine.new()
      |> Engine.add_rules([rule])
      |> Engine.add_facts([
        {"user:alice", :follows, "user:bob"},
        {"user:bob", :name, "Bob"},
        {"user:alice", :name, "Alice"},
        {"user:bob", :follows, "user:alice"}
      ])

    assert Engine.query(
             engine,
             clauses([
               {alice_id, :name, "Alice"},
               {bob_id, :name, "Bob"},
               {alice_id, :follows, bob_id},
               {bob_id, :follows, alice_id}
             ])
           ) ==
             MapSet.new([
               %Activation{
                 rule_id: {Ruler.Engine, :query},
                 facts: [
                   {"user:alice", :name, "Alice"},
                   {"user:bob", :name, "Bob"},
                   {"user:alice", :follows, "user:bob"},
                   {"user:bob", :follows, "user:alice"}
                 ],
                 bindings: %{alice_id: "user:alice", bob_id: "user:bob"}
               }
             ])

    assert Engine.query(engine, clauses([{follower, :follows, followed}])) ==
             MapSet.new([
               %Activation{
                 rule_id: {Ruler.Engine, :query},
                 facts: [{"user:alice", :follows, "user:bob"}],
                 bindings: %{follower: "user:alice", followed: "user:bob"}
               },
               %Activation{
                 rule_id: {Ruler.Engine, :query},
                 facts: [{"user:bob", :follows, "user:alice"}],
                 bindings: %{follower: "user:bob", followed: "user:alice"}
               }
             ])
  end

  test "simple disjunction on its own" do
    rule =
      rule :solo_disjunction_test do
        {user_id, :name, "Alice"} | {user_id, :name, "Bob"} -> []
      end

    engine =
      Engine.new()
      |> Engine.add_rules([rule])
      |> Engine.add_facts([
        {"user:1", :name, "Bob"}
      ])

    expected_activation = %Activation{
      rule_id: :solo_disjunction_test,
      facts: [
        {"user:1", :name, "Bob"}
      ],
      bindings: %{user_id: "user:1"}
    }

    assert engine.log == [
             {:activation_event, {:activate, expected_activation}},
             {:fact_was_added, {"user:1", :name, "Bob"}},
             {:add_fact_source, {"user:1", :name, "Bob"}, :explicit_assertion},
             {:instruction, {:add_fact, {"user:1", :name, "Bob"}}},
             {:instruction, {:add_rule, rule}}
           ]
  end

  test "disjunction sharing variables with sibling conditions" do
    rule =
      rule :disjunction_test do
        [
          {user_id, :type, :user},
          {user_id, :name, user_name},
          {user_id, :is_admin, true}
          | [{:access_overrides, :name, user_name}, {:access_overrides, :active, true}]
        ] ->
          []
      end

    engine =
      Engine.new()
      |> Engine.add_rules([rule])
      |> Engine.add_facts([
        {"user:alice", :type, :user},
        {"user:alice", :name, "Alice"},
        {:access_overrides, :name, "Alice"},
        {:access_overrides, :active, true},
        {"user:alice", :is_admin, true}
      ])

    first_expected_activation = %Activation{
      rule_id: :disjunction_test,
      facts: [
        {"user:alice", :type, :user},
        {"user:alice", :name, "Alice"},
        {:access_overrides, :name, "Alice"},
        {:access_overrides, :active, true}
      ],
      bindings: %{user_id: "user:alice", user_name: "Alice"}
    }

    second_expected_activation = %Activation{
      rule_id: :disjunction_test,
      facts: [
        {"user:alice", :type, :user},
        {"user:alice", :name, "Alice"},
        {"user:alice", :is_admin, true}
      ],
      bindings: %{user_id: "user:alice", user_name: "Alice"}
    }

    assert engine.log == [
             {:activation_event, {:activate, second_expected_activation}},
             {:fact_was_added, {"user:alice", :is_admin, true}},
             {:add_fact_source, {"user:alice", :is_admin, true}, :explicit_assertion},
             {:instruction, {:add_fact, {"user:alice", :is_admin, true}}},
             {:activation_event, {:activate, first_expected_activation}},
             {:fact_was_added, {:access_overrides, :active, true}},
             {:add_fact_source, {:access_overrides, :active, true}, :explicit_assertion},
             {:instruction, {:add_fact, {:access_overrides, :active, true}}},
             {:fact_was_added, {:access_overrides, :name, "Alice"}},
             {:add_fact_source, {:access_overrides, :name, "Alice"}, :explicit_assertion},
             {:instruction, {:add_fact, {:access_overrides, :name, "Alice"}}},
             {:fact_was_added, {"user:alice", :name, "Alice"}},
             {:add_fact_source, {"user:alice", :name, "Alice"}, :explicit_assertion},
             {:instruction, {:add_fact, {"user:alice", :name, "Alice"}}},
             {:fact_was_added, {"user:alice", :type, :user}},
             {:add_fact_source, {"user:alice", :type, :user}, :explicit_assertion},
             {:instruction, {:add_fact, {"user:alice", :type, :user}}},
             {:instruction, {:add_rule, rule}}
           ]
  end

  test "query macro" do
    rule =
      rule :mutual_follow do
        [
          {x, :follows, y},
          {y, :follows, x}
        ] ->
          [
            imply({x, :mutually_follows, y})
          ]
      end

    engine =
      Engine.new()
      |> Engine.add_rules([rule])
      |> Engine.add_facts([
        {"alice", :follows, "bob"},
        {"bob", :follows, "alice"},
        {"eve", :follows, "alice"}
      ])

    follow_pairs =
      query engine do
        [
          {x, :mutually_follows, y}
        ] ->
          {x, y}
      end

    assert follow_pairs ==
             MapSet.new([
               {"alice", "bob"},
               {"bob", "alice"}
             ])
  end
end
