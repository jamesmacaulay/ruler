defmodule Ruler.Engine do
  alias Ruler.{
    Engine,
    Fact,
    Rule,
    State
  }

  @type state :: State.t()
  @type fact :: Fact.t()
  @type rule :: Rule.t()

  @spec add_fact(state, fact) :: state
  def add_fact(state, fact) do
    state = %{state | facts: Map.put(state.facts, fact, State.FactInfo.new())}
    Engine.ConstantTestNode.activate(state, state.alpha_top_node, fact, :add)
  end

  @spec remove_fact(state, fact) :: state
  def remove_fact(state, fact) do
    state = %{state | facts: Map.delete(state.facts, fact)}
    Engine.ConstantTestNode.activate(state, state.alpha_top_node, fact, :remove)
  end

  @spec add_rule(state, rule) :: state
  def add_rule(state, rule) do
    state = %{state | latest_activation_events: [], rules: Map.put(state.rules, rule.id, rule)}
    {state, _} = Engine.ActivationNode.build(state, rule)
    state
  end
end
