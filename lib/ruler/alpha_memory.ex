defmodule Ruler.AlphaMemory do
  alias Ruler.{
    AlphaMemory,
    Fact,
    JoinNode,
    RefMap,
    State
  }

  @enforce_keys [:facts, :join_nodes]
  defstruct [:facts, :join_nodes]

  @type t :: %__MODULE__{
          facts: MapSet.t(Fact.t()),
          join_nodes: [JoinNode.ref()]
        }
  @type ref :: RefMap.ref()

  @spec activate(State.t(), AlphaMemory.ref(), Fact.t()) ::
          State.t()
  def activate(state = %State{}, alpha_memory_ref, fact) do
    {refs, alpha_memory} =
      RefMap.update_and_fetch!(
        state.refs,
        alpha_memory_ref,
        fn alpha_memory = %AlphaMemory{} ->
          %{
            alpha_memory
            | facts: MapSet.put(alpha_memory.facts, fact)
          }
        end
      )

    Enum.reduce(alpha_memory.join_nodes, %{state | refs: refs}, fn join_node_ref, state ->
      JoinNode.right_activate(state, join_node_ref, fact)
    end)
  end
end
