defmodule Ruler.AlphaMemory do
  @enforce_keys [:facts, :join_nodes]
  defstruct [:facts, :join_nodes]

  @type t :: %__MODULE__{
          facts: MapSet.t(Ruler.Fact.t()),
          join_nodes: [Ruler.RefMap.ref()]
        }

  @spec activate(Ruler.State.t(), Ruler.RefMap.ref(), Ruler.Fact.t()) :: Ruler.State.t()
  def activate(state = %Ruler.State{}, alpha_memory_ref, fact) do
    {refs, alpha_memory} =
      Ruler.RefMap.update_and_fetch!(
        state.refs,
        alpha_memory_ref,
        fn alpha_memory = %Ruler.AlphaMemory{} ->
          %{
            alpha_memory
            | facts: MapSet.put(alpha_memory.facts, fact)
          }
        end
      )

    Enum.reduce(alpha_memory.join_nodes, %{state | refs: refs}, fn join_node_ref, state ->
      Ruler.JoinNode.right_activate(state, join_node_ref, fact)
    end)
  end
end
