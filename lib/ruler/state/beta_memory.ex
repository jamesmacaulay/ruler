defmodule Ruler.State.BetaMemory do
  alias Ruler.{
    Fact,
    State
  }

  @enforce_keys [:parent_ref, :child_refs, :partial_activations]
  defstruct [:parent_ref, :child_refs, :partial_activations]

  @type partial_activation :: [Fact.t() | nil]
  @type t :: %__MODULE__{
          parent_ref: parent_ref | nil,
          child_refs: MapSet.t(child_ref),
          # "items":
          partial_activations: MapSet.t(partial_activation)
        }
  @type ref :: State.RefMap.ref(:beta_memory_ref)
  @type parent_ref :: State.JoinNode.ref() | State.NegativeNode.ref()
  # only the dummy top node can have negative nodes as children
  @type child_ref :: State.JoinNode.ref() | State.NegativeNode.ref()

  @spec new(parent_ref) :: State.BetaMemory.t()
  def new(parent_ref) do
    %State.BetaMemory{
      parent_ref: parent_ref,
      child_refs: MapSet.new(),
      partial_activations: MapSet.new()
    }
  end

  @spec top_node_ref() :: ref
  def top_node_ref() do
    {:beta_memory_ref, 0}
  end
end
