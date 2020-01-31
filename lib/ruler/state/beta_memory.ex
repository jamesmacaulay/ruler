defmodule Ruler.State.BetaMemory do
  alias Ruler.{
    Fact,
    State
  }

  @enforce_keys [:parent, :children, :partial_activations]
  defstruct [:parent, :children, :partial_activations]

  @type partial_activation :: [Fact.t()]
  @type t :: %__MODULE__{
          parent: parent_ref | nil,
          children: MapSet.t(State.JoinNode.ref()),
          # "items":
          partial_activations: MapSet.t(partial_activation)
        }
  @type ref :: {:beta_memory_ref, State.RefMap.ref()}
  @type parent_ref :: State.JoinNode.ref()

  @spec new(parent_ref) :: State.BetaMemory.t()
  def new(parent_ref) do
    %State.BetaMemory{
      parent: parent_ref,
      children: MapSet.new(),
      partial_activations: MapSet.new()
    }
  end
end
