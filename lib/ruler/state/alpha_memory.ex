defmodule Ruler.State.AlphaMemory do
  alias Ruler.{
    Fact,
    State
  }

  @enforce_keys [:facts, :join_node_refs]
  defstruct [:facts, :join_node_refs]

  @type t :: %__MODULE__{
          # items
          facts: MapSet.t(Fact.t()),
          # successors
          join_node_refs: [State.JoinNode.ref()]
        }
  @type ref :: {:alpha_memory_ref, State.RefMap.ref()}

  @spec new() :: State.AlphaMemory.t()
  def new() do
    %State.AlphaMemory{
      facts: MapSet.new(),
      join_node_refs: []
    }
  end
end
