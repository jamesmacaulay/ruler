defmodule Ruler.StateTest do
  use ExUnit.Case
  alias Ruler.{Rule, State}
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
end
