defmodule Ruler.Rule do
  @enforce_keys [:id, :conditions, :actions]
  defstruct [:id, :conditions, :actions]

  @type id :: any
  @type t :: %__MODULE__{
          id: id,
          conditions: [Ruler.Condition.t()],
          actions: [Ruler.Action.t()]
        }
end
