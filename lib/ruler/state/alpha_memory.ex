defmodule Ruler.State.AlphaMemory do
  alias Ruler.{
    Fact,
    State
  }

  @enforce_keys [:facts, :beta_node_refs]
  defstruct [:facts, :beta_node_refs]

  @type t :: %__MODULE__{
          # items
          facts: MapSet.t(Fact.t()),
          # successors
          beta_node_refs: [State.JoinNode.ref() | State.NegativeNode.ref()]
        }
  @type ref :: State.RefMap.ref(:alpha_memory_ref)

  @spec new() :: State.AlphaMemory.t()
  def new() do
    %State.AlphaMemory{
      facts: MapSet.new(),
      beta_node_refs: []
    }
  end
end
