defmodule Ruler.StateTest do
  use ExUnit.Case
  alias Ruler.State
  doctest Ruler.State

  test "add_fact, remove_fact, has_fact? updates and reads from state" do
    fact = {:alice, :follows, :bob}
    state = State.new()

    assert !State.has_fact?(state, fact)

    {state, _} = State.add_fact(state, fact)

    assert State.has_fact?(state, fact)

    {state, _} = State.remove_fact(state, fact)

    assert !State.has_fact?(state, fact)
  end

  test "add_rule, has_rule? updates and reads from state" do
    rule = %Ruler.Rule{
      id: :mutual_follow,
      conditions: [
        {{:var, :x}, {:const, :follows}, {:var, :y}},
        {{:var, :y}, {:const, :follows}, {:var, :x}}
      ],
      actions: []
    }

    state = State.new()

    assert !State.has_rule?(state, :mutual_follow)

    {state, _} = State.add_rule(state, rule)

    assert State.has_rule?(state, :mutual_follow)
  end
end
