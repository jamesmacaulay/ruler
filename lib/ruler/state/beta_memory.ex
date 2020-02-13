defmodule Ruler.State.BetaMemory do
  alias Ruler.{
    Fact,
    State
  }

  @enforce_keys [:parent_ref, :child_refs, :partial_activations]
  defstruct [:parent_ref, :child_refs, :partial_activations]

  @type partial_activation :: [Fact.t()]
  @type t :: %__MODULE__{
          parent_ref: parent_ref | nil,
          child_refs: MapSet.t(State.JoinNode.ref()),
          # "items":
          partial_activations: MapSet.t(partial_activation)
        }
  @type ref :: {:beta_memory_ref, State.RefMap.ref()}
  @type parent_ref :: State.JoinNode.ref()

  @spec new(parent_ref) :: State.BetaMemory.t()
  def new(parent_ref) do
    %State.BetaMemory{
      parent_ref: parent_ref,
      child_refs: MapSet.new(),
      partial_activations: MapSet.new()
    }
  end
end
