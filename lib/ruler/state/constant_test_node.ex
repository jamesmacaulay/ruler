defmodule Ruler.State.ConstantTestNode do
  alias Ruler.{
    Fact,
    State
  }

  @enforce_keys [:field, :target_value, :alpha_memory, :children]
  defstruct [:field, :target_value, :alpha_memory, :children]

  @type t :: %__MODULE__{
          # field-to-test
          field: Fact.field_index() | nil,
          # thing-the-field-must-equal
          target_value: any(),
          # output-memory
          alpha_memory: State.AlphaMemory.ref() | nil,
          children: [State.ConstantTestNode.ref()]
        }
  @type ref :: {:constant_test_node_ref, State.RefMap.ref()}

  @spec matches_fact?(State.ConstantTestNode.t(), Fact.t()) :: boolean
  def matches_fact?(node, fact) do
    field_index = node.field
    field_index == nil || elem(fact, field_index) == node.target_value
  end
end
