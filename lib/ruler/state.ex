defmodule Ruler.State do
  alias Ruler.{
    Fact,
    FactInfo,
    RefMap,
    Rule,
    State
  }

  defstruct facts: MapSet.new(), rules: %{}, refs: RefMap.new()

  @type t :: %__MODULE__{
          facts: %{Fact.t() => FactInfo.t()},
          rules: %{Rule.id() => Rule.t()},
          refs: RefMap.t()
        }

  @spec new :: State.t()
  def new do
    %__MODULE__{}
  end

  @spec add_fact(State.t(), Fact.t()) :: {State.t(), {[], []}}
  def add_fact(state = %__MODULE__{facts: facts}, fact) do
    {
      %{state | facts: MapSet.put(facts, fact)},
      {[], []}
    }
  end

  @spec remove_fact(State.t(), Fact.t()) :: {State.t(), {[], []}}
  def remove_fact(state = %__MODULE__{facts: facts}, fact) do
    {
      %{state | facts: MapSet.delete(facts, fact)},
      {[], []}
    }
  end

  @spec has_fact?(State.t(), Fact.t()) :: boolean
  def has_fact?(_state = %__MODULE__{facts: facts}, fact) do
    MapSet.member?(facts, fact)
  end

  @spec add_rule(State.t(), Rule.t()) :: {State.t(), {[], []}}
  def add_rule(state = %__MODULE__{rules: rules}, rule) do
    {
      %{state | rules: Map.put(rules, rule.id, rule)},
      {[], []}
    }
  end

  @spec has_rule?(State.t(), Rule.id()) :: boolean
  def has_rule?(_state = %__MODULE__{rules: rules}, id) do
    Map.has_key?(rules, id)
  end
end
