defmodule Ruler.State.JoinNode do
  alias Ruler.{
    Condition,
    Fact,
    State
  }

  alias Ruler.State.{
    ActivationNode,
    AlphaMemory,
    BetaMemory,
    JoinNode,
    RefMap
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

  @spec build_or_share(State.t(), BetaMemory.ref(), AlphaMemory.ref(), [Comparison.t()]) ::
          {State.t(), JoinNode.ref()}
  def build_or_share(
        state = %State{},
        parent_ref = {:beta_memory_ref, _},
        alpha_memory_ref = {:alpha_memory_ref, _},
        comparisons
      ) do
    parent = RefMap.fetch!(state.beta_memories, parent_ref)

    suitable_child_ref =
      Enum.find(parent.children, fn child_ref ->
        case child_ref do
          {:join_node_ref, _} ->
            child = RefMap.fetch!(state.join_nodes, child_ref)
            child.alpha_memory == alpha_memory_ref && child.comparisons == comparisons

          _ ->
            false
        end
      end)

    case suitable_child_ref do
      {:join_node_ref, _} ->
        {state, suitable_child_ref}

      nil ->
        new_join_node = %__MODULE__{
          parent: parent_ref,
          children: [],
          alpha_memory: alpha_memory_ref,
          comparisons: comparisons
        }

        {join_nodes, new_join_node_ref} = RefMap.insert(state.join_nodes, new_join_node)

        alpha_memories =
          RefMap.update!(state.alpha_memories, alpha_memory_ref, fn alpha_memory ->
            %{alpha_memory | join_nodes: [new_join_node_ref | alpha_memory.join_nodes]}
          end)

        beta_memories =
          RefMap.update!(state.beta_memories, parent_ref, fn beta_memory ->
            %{beta_memory | children: MapSet.put(beta_memory.children, new_join_node_ref)}
          end)

        state = %{
          state
          | join_nodes: join_nodes,
            alpha_memories: alpha_memories,
            beta_memories: beta_memories
        }

        {state, new_join_node_ref}
    end
  end

  @spec comparisons_from_condition(Condition.t(), [Condition.t()]) :: [Comparison.t()]
  def comparisons_from_condition(condition, earlier_conditions) do
    Condition.indexed_variables(condition)
    |> Enum.reduce([], fn {field_index, variable_name}, result ->
      matching_earlier_indexes =
        earlier_conditions
        |> Enum.with_index()
        |> Enum.find_value(fn {earlier_condition, earlier_condition_index} ->
          matching_earlier_indexed_variable =
            earlier_condition
            |> Condition.indexed_variables()
            |> Enum.find(fn {_earlier_field_index, earlier_variable_name} ->
              variable_name == earlier_variable_name
            end)

          with {earlier_field_index, _} <- matching_earlier_indexed_variable do
            {earlier_condition_index, earlier_field_index}
          end
        end)

      case matching_earlier_indexes do
        nil ->
          result

        {earlier_condition_index, earlier_field_index} ->
          comparison = %Comparison{
            arg1_field: field_index,
            fact2_index: earlier_condition_index,
            arg2_field: earlier_field_index
          }

          [comparison | result]
      end
    end)
  end

  # when a new partial activation is added to the parent beta memory
  @spec left_activate(
          State.t(),
          JoinNode.ref(),
          BetaMemory.partial_activation()
        ) :: State.t()
  def left_activate(state = %State{}, join_node_ref = {:join_node_ref, _}, partial_activation) do
    join_node = %JoinNode{} = RefMap.fetch!(state.join_nodes, join_node_ref)

    alpha_memory_ref = {:alpha_memory_ref, _} = join_node.alpha_memory
    alpha_memory = %AlphaMemory{} = RefMap.fetch!(state.alpha_memories, alpha_memory_ref)

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
  def right_activate(state = %State{}, join_node_ref = {:join_node_ref, _}, fact) do
    join_node = %JoinNode{} = RefMap.fetch!(state.join_nodes, join_node_ref)

    parent_ref = {:beta_memory_ref, _} = join_node.parent
    parent = %BetaMemory{} = RefMap.fetch!(state.beta_memories, parent_ref)

    # fold parent.partial_activations into init_state by performing comparisons and left activations
    Enum.reduce(parent.partial_activations, state, fn partial_activation, state ->
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
