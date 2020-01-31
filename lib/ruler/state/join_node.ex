defmodule Ruler.State.JoinNode do
  alias Ruler.{
    Condition,
    Fact,
    State
  }

  @enforce_keys [:parent, :children, :alpha_memory, :comparisons]
  defstruct [:parent, :children, :alpha_memory, :comparisons]

  @type ref :: {:join_node_ref, State.RefMap.ref()}
  @type child_ref :: State.BetaMemory.ref() | State.ActivationNode.ref()

  @type t :: %__MODULE__{
          parent: State.BetaMemory.ref(),
          children: [State.JoinNode.child_ref()],
          alpha_memory: State.AlphaMemory.ref(),
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

    @spec perform(Comparison.t(), State.BetaMemory.partial_activation(), Fact.t()) :: boolean
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

  @spec perform_join_comparisons(
          [Comparison.t()],
          State.BetaMemory.partial_activation(),
          Fact.t()
        ) :: boolean()
  def perform_join_comparisons(comparisons, partial_activation, fact) do
    Enum.all?(comparisons, fn c -> Comparison.perform(c, partial_activation, fact) end)
  end
end
