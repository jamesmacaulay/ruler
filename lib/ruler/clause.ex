defmodule Ruler.Clause do
  alias Ruler.{
    Condition
  }

  @type t ::
          {:condition, Condition.t()}
          | {:any, [Condition.t()]}

  @spec conditions_from_clauses([t]) :: [Condition.t()]
  def conditions_from_clauses(clauses) do
    clauses
    |> Enum.map(fn
      {:condition, condition} -> condition
      {:any, [condition | _]} -> condition
    end)
  end
end
