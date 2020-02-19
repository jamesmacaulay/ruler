defmodule Ruler.Engine.FactInfo do
  alias Ruler.{
    Engine,
    EventContext,
    Fact,
    State
  }

  @type ctx :: EventContext.t()
  @type fact :: Fact.t()
  @type source :: State.FactInfo.source()

  @spec add_fact_source(ctx, fact, source) :: ctx
  def add_fact_source(ctx, fact, source) do
    state = ctx.state
    facts = state.facts

    case Map.fetch(facts, fact) do
      {:ok, fact_info} ->
        fact_info = State.FactInfo.add_source(fact_info, source)
        %{ctx | state: %{state | facts: Map.put(facts, fact, fact_info)}}

      :error ->
        fact_info = State.FactInfo.new(source)

        %{ctx | state: %{state | facts: Map.put(facts, fact, fact_info)}}
        |> Engine.ConstantTestNode.activate(state.alpha_top_node, fact, :add)
    end
  end

  def remove_fact_source(ctx, fact, source) do
    state = ctx.state
    facts = state.facts

    fact_info = Map.fetch!(facts, fact) |> State.FactInfo.remove_source(source)

    if State.FactInfo.baseless?(fact_info) do
      %{ctx | state: %{state | facts: Map.delete(facts, fact)}}
      |> Engine.ConstantTestNode.activate(state.alpha_top_node, fact, :remove)
    else
      %{ctx | state: %{state | facts: Map.put(facts, fact, fact_info)}}
    end
  end

  @spec baseless?(ctx, fact) :: boolean
  def baseless?(ctx, fact) do
    ctx.state.facts |> Map.fetch!(fact) |> State.FactInfo.baseless?()
  end
end
