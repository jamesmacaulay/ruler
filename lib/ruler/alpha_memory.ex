defmodule Ruler.AlphaMemory do
  alias Ruler.{
    AlphaMemory,
    Condition,
    ConstantTestNode,
    Fact,
    JoinNode,
    RefMap,
    State
  }

  defstruct facts: MapSet.new(), join_nodes: []

  @type t :: %__MODULE__{
          # items
          facts: MapSet.t(Fact.t()),
          # successors
          join_nodes: [JoinNode.ref()]
        }
  @type ref :: {:alpha_memory_ref, RefMap.ref()}

  @spec build_or_share(State.t(), Condition.t()) :: {State.t(), AlphaMemory.ref()}
  def build_or_share(state = %State{}, condition) do
    current_node_ref = state.alpha_top_node

    {state, current_node_ref} =
      Condition.constant_tests(condition)
      |> Enum.reduce({state, current_node_ref}, fn {field_index, constant_value},
                                                   {state, current_node_ref} ->
        ConstantTestNode.build_or_share(state, current_node_ref, field_index, constant_value)
      end)

    {:constant_test_node_ref, inner_current_node_ref} = current_node_ref
    current_node = RefMap.fetch!(state.constant_test_nodes, inner_current_node_ref)

    case current_node.alpha_memory do
      alpha_memory_ref = {:alpha_memory_ref, _} ->
        {state, alpha_memory_ref}

      nil ->
        alpha_memory = %__MODULE__{}

        {alpha_memories, inner_alpha_memory_ref} =
          RefMap.insert(state.alpha_memories, alpha_memory)

        alpha_memory_ref = {:alpha_memory_ref, inner_alpha_memory_ref}

        state = %{state | alpha_memories: alpha_memories}

        constant_test_nodes =
          RefMap.update!(
            state.constant_test_nodes,
            inner_current_node_ref,
            fn constant_test_node ->
              %{constant_test_node | alpha_memory: alpha_memory_ref}
            end
          )

        state = %{state | constant_test_nodes: constant_test_nodes}

        state =
          Enum.reduce(Map.keys(state.facts), state, fn fact, state ->
            if Condition.constant_tests_match_fact?(condition, fact) do
              activate(state, alpha_memory_ref, fact)
            else
              state
            end
          end)

        {state, alpha_memory_ref}
    end
  end

  @spec activate(State.t(), AlphaMemory.ref(), Fact.t()) ::
          State.t()
  def activate(state = %State{}, {:alpha_memory_ref, inner_alpha_memory_ref}, fact) do
    {alpha_memories, alpha_memory} =
      RefMap.update_and_fetch!(
        state.alpha_memories,
        inner_alpha_memory_ref,
        fn alpha_memory = %AlphaMemory{} ->
          %{
            alpha_memory
            | facts: MapSet.put(alpha_memory.facts, fact)
          }
        end
      )

    Enum.reduce(
      alpha_memory.join_nodes,
      %{state | alpha_memories: alpha_memories},
      fn join_node_ref, state ->
        JoinNode.right_activate(state, join_node_ref, fact)
      end
    )
  end
end
