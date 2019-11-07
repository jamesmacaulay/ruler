defmodule Ruler.State do
  defstruct facts: MapSet.new(), rules: %{}, refs: Ruler.RefMap.new()

  @type t :: %__MODULE__{
          facts: %{Ruler.Fact.t() => Ruler.FactInfo.t()},
          rules: %{Ruler.Rule.id() => Ruler.Rule.t()},
          refs: Ruler.RefMap.t()
        }

  @spec new :: Ruler.State.t()
  def new do
    %__MODULE__{}
  end

  @spec add_fact(Ruler.State.t(), Ruler.Fact.t()) :: {Ruler.State.t(), {[], []}}
  def add_fact(state = %__MODULE__{facts: facts}, fact) do
    {
      %{state | facts: MapSet.put(facts, fact)},
      {[], []}
    }
  end

  @spec remove_fact(Ruler.State.t(), Ruler.Fact.t()) :: {Ruler.State.t(), {[], []}}
  def remove_fact(state = %__MODULE__{facts: facts}, fact) do
    {
      %{state | facts: MapSet.delete(facts, fact)},
      {[], []}
    }
  end

  @spec has_fact?(Ruler.State.t(), Ruler.Fact.t()) :: boolean
  def has_fact?(_state = %__MODULE__{facts: facts}, fact) do
    MapSet.member?(facts, fact)
  end

  @spec add_rule(Ruler.State.t(), Ruler.Rule.t()) :: {Ruler.State.t(), {[], []}}
  def add_rule(state = %__MODULE__{rules: rules}, rule) do
    {
      %{state | rules: Map.put(rules, rule.id, rule)},
      {[], []}
    }
  end

  @spec has_rule?(Ruler.State.t(), Ruler.Rule.id()) :: boolean
  def has_rule?(_state = %__MODULE__{rules: rules}, id) do
    Map.has_key?(rules, id)
  end
end
