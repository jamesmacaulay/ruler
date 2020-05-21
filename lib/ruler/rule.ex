defmodule Ruler.Rule do
  @enforce_keys [:id, :clauses, :actions]
  defstruct [:id, :clauses, :actions]

  @type id :: any
  @type t :: %__MODULE__{
          id: id,
          clauses: [Ruler.Clause.t()],
          actions: [Ruler.Action.t()]
        }
end
