defmodule Ruler.JoinNode do
  alias Ruler.{
    ActivationNode,
    AlphaMemory,
    BetaMemory,
    Fact,
    JoinNode,
    RefMap,
    State
  }

  @enforce_keys [:parent, :children, :alpha_memory, :comparisons]
  defstruct [:parent, :children, :alpha_memory, :comparisons]

  @type ref :: {:join_node_ref, RefMap.ref()}
  @type child_ref :: BetaMemory.ref() | ActivationNode.ref()

  @type t :: %__MODULE__{
          parent: BetaMemory.ref(),
          children: [JoinNode.child_ref()],
          alpha_memory: AlphaMemory.ref(),
          comparisons: [Comparison.t()]
        }

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
  def left_activate(state = %State{}, {:join_node_ref, inner_join_node_ref}, partial_activation) do
    join_node = %JoinNode{} = RefMap.fetch!(state.join_nodes, inner_join_node_ref)
    alpha_memory = %AlphaMemory{} = RefMap.fetch!(state.alpha_memories, join_node.alpha_memory)

    Enum.reduce(alpha_memory.facts, state, fn fact, state ->
      compare_and_activate_children(state, join_node, partial_activation, fact)
    end)
  end

  @spec compare_and_activate_children(
          Ruler.State.t(),
          JoinNode.t(),
          BetaMemory.partial_activation(),
          Fact.t()
        ) :: State.t()
  def compare_and_activate_children(
        state = %State{},
        join_node = %JoinNode{},
        partial_activation,
        fact
      ) do
    if perform_join_comparisons(join_node.comparisons, partial_activation, fact) do
      Enum.reduce(join_node.children, state, fn child_node_ref, state ->
        left_activate_child(state, child_node_ref, partial_activation, fact)
      end)
    else
      state
    end
  end

  @spec left_activate_child(
          State.t(),
          JoinNode.child_ref(),
          BetaMemory.partial_activation(),
          Fact.t()
        ) ::
          State.t()
  defp left_activate_child(state = %State{}, child_ref, partial_activation, fact) do
    case child_ref do
      {:beta_memory_ref, _} ->
        BetaMemory.left_activate(state, child_ref, partial_activation, fact)

      {:activation_node_ref, _} ->
        ActivationNode.left_activate(state, child_ref, partial_activation, fact)
    end
  end

  # when a new fact is added to the alpha memory
  @spec right_activate(State.t(), JoinNode.ref(), Fact.t()) ::
          State.t()
  def right_activate(state = %State{}, {:join_node_ref, inner_join_node_ref}, fact) do
    join_node = %JoinNode{} = RefMap.fetch!(state.join_nodes, inner_join_node_ref)

    # fold join_node.parent.partial_activations into init_state by performing comparisons and left activations
    Enum.reduce(join_node.parent.partial_activations, state, fn partial_activation, state ->
      compare_and_activate_children(state, join_node, partial_activation, fact)
    end)
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
