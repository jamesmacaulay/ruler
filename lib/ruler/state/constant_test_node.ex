defmodule Ruler.State.ConstantTestNode do
  alias Ruler.{
    Fact,
    State
  }

  alias Ruler.State.{
    AlphaMemory,
    ConstantTestNode,
    RefMap
  }

  @enforce_keys [:field, :target_value, :alpha_memory, :children]
  defstruct [:field, :target_value, :alpha_memory, :children]

  @type t :: %__MODULE__{
          # field-to-test
          field: Fact.field_index() | nil,
          # thing-the-field-must-equal
          target_value: any(),
          # output-memory
          alpha_memory: AlphaMemory.ref() | nil,
          children: [ConstantTestNode.ref()]
        }
  @type ref :: {:constant_test_node_ref, RefMap.ref()}

  @spec build_or_share(State.t(), ConstantTestNode.ref(), Fact.field_index(), term()) ::
          {State.t(), ConstantTestNode.ref()}
  def build_or_share(
        state,
        parent_ref = {:constant_test_node_ref, _},
        field_index,
        constant_value
      ) do
    parent = RefMap.fetch!(state.constant_test_nodes, parent_ref)

    suitable_child_ref =
      Enum.find(parent.children, fn child_ref = {:constant_test_node_ref, _} ->
        child = RefMap.fetch!(state.constant_test_nodes, child_ref)
        child.field == field_index && child.target_value == constant_value
      end)

    case suitable_child_ref do
      {:constant_test_node_ref, _} ->
        {state, suitable_child_ref}

      nil ->
        child = %__MODULE__{
          field: field_index,
          target_value: constant_value,
          alpha_memory: nil,
          children: []
        }

        {constant_test_nodes, child_ref} = RefMap.insert(state.constant_test_nodes, child)

        constant_test_nodes =
          constant_test_nodes
          |> RefMap.update!(parent_ref, fn parent ->
            %{parent | children: [child_ref | parent.children]}
          end)

        state = %{state | constant_test_nodes: constant_test_nodes}

        {state, child_ref}
    end
  end

  def activate(
        state = %State{},
        constant_test_node_ref = {:constant_test_node_ref, _},
        fact
      ) do
    constant_test_node = RefMap.fetch!(state.constant_test_nodes, constant_test_node_ref)
    field_index = constant_test_node.field

    if field_index == nil || elem(fact, field_index) == constant_test_node.target_value do
      state =
        case constant_test_node.alpha_memory do
          nil ->
            state

          alpha_memory_ref ->
            AlphaMemory.activate(state, alpha_memory_ref, fact)
        end

      Enum.reduce(constant_test_node.children, state, fn child_ref, state ->
        activate(state, child_ref, fact)
      end)
    else
      state
    end
  end
end
