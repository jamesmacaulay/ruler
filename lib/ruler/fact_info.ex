defmodule Ruler.FactInfo do
  alias Ruler.{
    BetaMemory,
    RefMap
  }

  @enforce_keys []
  defstruct partial_activations: MapSet.new()

  @type t :: %__MODULE__{
          partial_activations: MapSet.t({RefMap.ref(), BetaMemory.partial_activation()})
        }
end
