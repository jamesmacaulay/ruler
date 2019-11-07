defmodule Ruler.BetaMemory do
  @enforce_keys [:parent, :children, :partial_activations]
  defstruct [:parent, :children, :partial_activations]

  @type partial_activation :: [Ruler.Fact.t()]
  @type t :: %__MODULE__{
          parent: Ruler.RefMap.ref(),
          children: MapSet.t(Ruler.RefMap.ref()),
          partial_activations: MapSet.t(partial_activation)
        }

  @spec left_activate(
          Ruler.State.t(),
          Ruler.RefMap.ref(),
          Ruler.BetaMemory.partial_activation(),
          Ruler.Fact.t()
        ) :: Ruler.State.t()
  def left_activate(
        state = %Ruler.State{},
        beta_memory_ref,
        partial_activation,
        fact
      ) do
    new_partial_activation = [fact | partial_activation]

    # add the new partial activation to the given beta memory in the state
    {refs, beta_memory} =
      Ruler.RefMap.update_and_fetch!(
        state.refs,
        beta_memory_ref,
        fn beta_memory = %Ruler.BetaMemory{} ->
          %{
            beta_memory
            | partial_activations:
                MapSet.put(beta_memory.partial_activations, new_partial_activation)
          }
        end
      )

    # for each fact in the new partial activation, update that fact's info in the state
    # to remember that this beta memory has a reference to that fact via this new partial activation
    facts =
      Enum.reduce(new_partial_activation, state.facts, fn fact, factmap ->
        Map.update!(factmap, fact, fn fact_info = %Ruler.FactInfo{} ->
          %{
            fact_info
            | partial_activations:
                MapSet.put(
                  fact_info.partial_activations,
                  {beta_memory_ref, new_partial_activation}
                )
          }
        end)
      end)

    # for each child join node of the beta memory, perform a left activation, and return the final state
    Enum.reduce(
      beta_memory.children,
      %{state | facts: facts, refs: refs},
      fn join_node_ref, state ->
        Ruler.JoinNode.left_activate(state, join_node_ref, new_partial_activation)
      end
    )
  end
end
