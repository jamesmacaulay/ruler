defmodule Ruler.Engine do
  alias Ruler.{
    Engine,
    EventContext,
    Fact,
    Rule,
    State
  }

  @type state :: State.t()
  @type fact :: Fact.t()
  @type rule :: Rule.t()
  @type ctx :: EventContext.t()

  @spec add_fact(state, fact) :: ctx
  def add_fact(state, fact) do
    EventContext.run_with_effects(state, {:add_fact, fact}, fn ctx ->
      Engine.FactInfo.add_fact_source(ctx, fact, :explicit_assertion)
    end)
  end

  @spec remove_fact(state, fact) :: ctx
  def remove_fact(state, fact) do
    EventContext.run_with_effects(state, {:remove_fact, fact}, fn ctx ->
      Engine.FactInfo.remove_fact_source(ctx, fact, :explicit_assertion)
    end)
  end

  @spec add_rule(state, rule) :: ctx
  def add_rule(state, rule) do
    EventContext.run_with_effects(state, {:add_rule, rule}, fn ctx ->
      %{ctx | state: %{state | rules: Map.put(state.rules, rule.id, rule)}}
      |> Engine.ActivationNode.build(rule)
    end)
  end
end
