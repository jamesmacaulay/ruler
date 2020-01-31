defmodule Ruler.State.FactInfo do
  alias Ruler.{
    State
  }

  @enforce_keys []
  defstruct partial_activations: MapSet.new()

  @type t :: %__MODULE__{
          partial_activations:
            MapSet.t({State.BetaMemory.ref(), State.BetaMemory.partial_activation()})
        }

  @spec new() :: State.FactInfo.t()
  def new() do
    %__MODULE__{}
  end
end
