defmodule Ruler.Engine.FactInfo do
  alias Ruler.{
    Engine,
    Fact,
    State
  }

  @type engine :: Engine.t()
  @type fact :: Fact.t()
  @type source :: State.FactInfo.source()

  @spec add_fact_source(engine, fact, source) :: engine
  def add_fact_source(engine, fact, source) do
    engine = Engine.add_log_event(engine, {:add_fact_source, fact, source})
    state = engine.state
    facts = state.facts

    case Map.fetch(facts, fact) do
      {:ok, fact_info} ->
        fact_info = State.FactInfo.add_source(fact_info, source)
        %{engine | state: %{state | facts: Map.put(facts, fact, fact_info)}}

      :error ->
        fact_info = State.FactInfo.new(source)

        %{engine | state: %{state | facts: Map.put(facts, fact, fact_info)}}
        |> Engine.add_log_event({:fact_was_added, fact})
        |> Engine.ConstantTestNode.activate(State.ConstantTestNode.top_node_ref(), fact, :add)
    end
  end

  def remove_fact_source(engine, fact, source) do
    engine = Engine.add_log_event(engine, {:remove_fact_source, fact, source})
    state = engine.state
    facts = state.facts

    fact_info = Map.fetch!(facts, fact) |> State.FactInfo.remove_source(source)

    if State.FactInfo.baseless?(fact_info) do
      %{engine | state: %{state | facts: Map.delete(facts, fact)}}
      |> Engine.add_log_event({:fact_was_removed, fact})
      |> Engine.ConstantTestNode.activate(State.ConstantTestNode.top_node_ref(), fact, :remove)
    else
      %{engine | state: %{state | facts: Map.put(facts, fact, fact_info)}}
    end
  end

  @spec baseless?(engine, fact) :: boolean
  def baseless?(engine, fact) do
    engine.state.facts |> Map.fetch!(fact) |> State.FactInfo.baseless?()
  end
end
