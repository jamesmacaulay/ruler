defmodule Ruler.FactInfo do
  alias Ruler.{
    BetaMemory,
    FactInfo
  }

  @enforce_keys []
  defstruct partial_activations: MapSet.new()

  @type t :: %__MODULE__{
          partial_activations: MapSet.t({BetaMemory.ref(), BetaMemory.partial_activation()})
        }

  @spec new() :: FactInfo.t()
  def new() do
    %__MODULE__{}
  end
end
