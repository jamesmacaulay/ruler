defmodule Ruler.State.ConstantTestNode do
  alias Ruler.{
    Fact,
    State
  }

  @enforce_keys [:field_index, :target_value, :alpha_memory_ref, :child_refs]
  defstruct [:field_index, :target_value, :alpha_memory_ref, :child_refs]

  @type t :: %__MODULE__{
          # field-to-test
          field_index: Fact.field_index() | nil,
          # thing-the-field-must-equal
          target_value: any(),
          # output-memory
          alpha_memory_ref: State.AlphaMemory.ref() | nil,
          child_refs: [State.ConstantTestNode.ref()]
        }
  @type ref :: State.RefMap.ref(:constant_test_node_ref)

  @spec matches_fact?(State.ConstantTestNode.t(), Fact.t()) :: boolean
  def matches_fact?(node, fact) do
    field_index = node.field_index
    field_index == nil || elem(fact, field_index) == node.target_value
  end

  @spec top_node_ref() :: ref
  def top_node_ref do
    {:constant_test_node_ref, 0}
  end
end
