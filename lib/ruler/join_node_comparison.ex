defmodule Ruler.JoinNodeComparison do
  alias Ruler.{
    BetaMemory,
    Fact,
    JoinNodeComparison
  }

  @enforce_keys [:arg1_field, :arg2_relative_condition_distance, :arg2_field]
  defstruct [:arg1_field, :arg2_relative_condition_distance, :arg2_field]

  @type t :: %__MODULE__{
          arg1_field: Fact.field_index(),
          arg2_relative_condition_distance: non_neg_integer,
          arg2_field: Fact.field_index()
        }

  @spec perform(JoinNodeComparison.t(), BetaMemory.partial_activation(), Fact.t()) :: boolean
  def perform(comparison, partial_activation, fact) do
    true
  end
end
