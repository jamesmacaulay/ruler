defmodule Ruler.State.AlphaMemory do
  alias Ruler.{
    Fact,
    State
  }

  @enforce_keys [:facts, :join_nodes]
  defstruct [:facts, :join_nodes]

  @type t :: %__MODULE__{
          # items
          facts: MapSet.t(Fact.t()),
          # successors
          join_nodes: [State.JoinNode.ref()]
        }
  @type ref :: {:alpha_memory_ref, State.RefMap.ref()}

  @spec new() :: State.AlphaMemory.t()
  def new() do
    %State.AlphaMemory{
      facts: MapSet.new(),
      join_nodes: []
    }
  end
end
