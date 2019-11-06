defmodule Ruler.Rule do
  @enforce_keys [:id, :conditions, :actions]
  defstruct [:id, :conditions, :actions]

  @type t :: %__MODULE__{
          id: term,
          conditions: [Ruler.Condition.t()],
          actions: [Ruler.Action.t()]
        }
end
