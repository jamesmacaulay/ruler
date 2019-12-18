defmodule Ruler.JoinNode do
  alias Ruler.{
    AlphaMemory,
    BetaMemory,
    Fact,
    JoinNode,
    RefMap,
    ReteNode,
    State
  }

  @enforce_keys [:parent, :children, :alpha_memory, :comparisons]
  defstruct [:parent, :children, :alpha_memory, :comparisons]

  @type t :: %__MODULE__{
          parent: BetaMemory.ref(),
          children: [ReteNode.ref()],
          alpha_memory: AlphaMemory.ref(),
          comparisons: [Foo.t()]
        }
  @type ref :: RefMap.ref()

  defmodule Comparison do
    @enforce_keys [:arg1_field, :fact2_index, :arg2_field]
    defstruct [:arg1_field, :fact2_index, :arg2_field]

    @type t :: %__MODULE__{
            arg1_field: Fact.field_index(),
            fact2_index: non_neg_integer,
            arg2_field: Fact.field_index()
          }

    @spec perform(Comparison.t(), BetaMemory.partial_activation(), Fact.t()) :: boolean
    def perform(
          comparison = %Comparison{},
          partial_activation,
          fact
        ) do
      arg1 = elem(fact, comparison.arg1_field)
      fact2 = Enum.fetch!(partial_activation, comparison.fact2_index)
      arg2 = elem(fact2, comparison.arg2_field)
      arg1 == arg2
    end
  end

  # when a new partial activation is added to the parent beta memory
  @spec left_activate(
          State.t(),
          JoinNode.ref(),
          BetaMemory.partial_activation()
        ) :: State.t()
  def left_activate(state = %State{}, join_node_ref, partial_activation) do
    # TODO
    state
  end

  # when a new fact is added to the alpha memory
  @spec right_activate(State.t(), JoinNode.ref(), Fact.t()) ::
          State.t()
  def right_activate(state = %State{}, join_node_ref, fact) do
    join_node = %JoinNode{} = RefMap.fetch!(state.refs, join_node_ref)

    # fold join_node.parent.partial_activations into state by performing comparisons and left activations
    state
  end

  @spec perform_join_comparisons(
          [Comparison.t()],
          BetaMemory.partial_activation(),
          Fact.t()
        ) :: boolean()
  def perform_join_comparisons(comparisons, partial_activation, fact) do
    Enum.all?(comparisons, fn c -> Comparison.perform(c, partial_activation, fact) end)
  end
end
