defmodule Ruler.BetaMemory do
  alias Ruler.{
    BetaMemory,
    Fact,
    FactInfo,
    JoinNode,
    RefMap,
    ReteNode,
    State
  }

  @enforce_keys [:parent, :children, :partial_activations]
  defstruct [:parent, :children, :partial_activations]

  @type partial_activation :: [Fact.t()]
  @type t :: %__MODULE__{
          parent: ReteNode.ref(),
          children: MapSet.t(ReteNode.ref()),
          partial_activations: MapSet.t(partial_activation)
        }
  @type ref :: RefMap.ref()

  @spec left_activate(
          State.t(),
          BetaMemory.ref(),
          BetaMemory.partial_activation(),
          Fact.t()
        ) :: State.t()
  def left_activate(
        state = %State{},
        beta_memory_ref,
        partial_activation,
        fact
      ) do
    new_partial_activation = [fact | partial_activation]

    # add the new partial activation to the given beta memory in the state
    {refs, beta_memory} =
      RefMap.update_and_fetch!(
        state.refs,
        beta_memory_ref,
        fn beta_memory = %BetaMemory{} ->
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
        Map.update!(factmap, fact, fn fact_info = %FactInfo{} ->
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
        JoinNode.left_activate(state, join_node_ref, new_partial_activation)
      end
    )
  end
end
