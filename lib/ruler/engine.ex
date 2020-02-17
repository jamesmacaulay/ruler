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
    state = %{state | facts: Map.put(state.facts, fact, State.FactInfo.new())}

    ctx =
      EventContext.new(state, {:add_fact, fact})
      |> Engine.ConstantTestNode.activate(state.alpha_top_node, fact, :add)
      |> EventContext.finalize()

    EventContext.perform_activation_effects(ctx)
    ctx
  end

  @spec remove_fact(state, fact) :: ctx
  def remove_fact(state, fact) do
    state = %{state | facts: Map.delete(state.facts, fact)}

    ctx =
      EventContext.new(state, {:remove_fact, fact})
      |> Engine.ConstantTestNode.activate(state.alpha_top_node, fact, :remove)
      |> EventContext.finalize()

    EventContext.perform_activation_effects(ctx)
    ctx
  end

  @spec add_rule(state, rule) :: ctx
  def add_rule(state, rule) do
    state = %{state | rules: Map.put(state.rules, rule.id, rule)}
    ctx = EventContext.new(state, {:add_rule, rule})
    {ctx, _} = Engine.ActivationNode.build(ctx, rule)

    ctx = EventContext.finalize(ctx)
    EventContext.perform_activation_effects(ctx)
    ctx
  end
end
