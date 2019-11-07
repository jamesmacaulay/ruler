defmodule Ruler.JoinNode do
  @enforce_keys [:parent, :children, :alpha_memory, :tests]
  defstruct [:parent, :children, :alpha_memory, :tests]

  @type t :: %__MODULE__{
          parent: Ruler.RefMap.ref(),
          children: [Ruler.RefMap.ref()],
          alpha_memory: Ruler.RefMap.ref(),
          tests: [{non_neg_integer, non_neg_integer, non_neg_integer}]
        }

  @spec left_activate(
          Ruler.State.t(),
          Ruler.RefMap.ref(),
          Ruler.BetaMemory.partial_activation()
        ) :: any
  def left_activate(state = %Ruler.State{}, join_node_ref, partial_activation) do
    state
  end

  @spec right_activate(Ruler.State.t(), Ruler.RefMap.ref(), Ruler.Fact.t()) :: Ruler.State.t()
  def right_activate(state = %Ruler.State{}, join_node_ref, fact) do
    state
  end
end
