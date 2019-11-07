defmodule Ruler.FactInfo do
  @enforce_keys []
  defstruct partial_activations: MapSet.new()

  @type t :: %__MODULE__{
          partial_activations:
            MapSet.t({Ruler.RefMap.ref(), Ruler.BetaMemory.partial_activation()})
        }
end
