defmodule Ruler.State.BetaMemory do
  alias Ruler.{
    Fact,
    State
  }

  alias Ruler.State.{
    BetaMemory,
    FactInfo,
    JoinNode,
    RefMap
  }

  @enforce_keys [:parent, :children, :partial_activations]
  defstruct [:parent, :children, :partial_activations]

  @type partial_activation :: [Fact.t()]
  @type t :: %__MODULE__{
          parent: parent_ref | nil,
          children: MapSet.t(JoinNode.ref()),
          # "items":
          partial_activations: MapSet.t(partial_activation)
        }
  @type ref :: {:beta_memory_ref, RefMap.ref()}
  @type parent_ref :: JoinNode.ref()

  @spec build_or_share(State.t(), parent_ref()) :: {State.t(), BetaMemory.ref()}
  def build_or_share(state, parent_ref = {:join_node_ref, _}) do
    parent = RefMap.fetch!(state.join_nodes, parent_ref)

    suitable_child_ref =
      Enum.find(parent.children, fn child_ref ->
        match?({:beta_memory_ref, _}, child_ref)
      end)

    case suitable_child_ref do
      {:beta_memory_ref, _} ->
        {state, suitable_child_ref}

      nil ->
        new_beta_memory = %__MODULE__{
          parent: parent_ref,
          children: MapSet.new(),
          partial_activations: MapSet.new()
        }

        {beta_memories, new_beta_memory_ref} = RefMap.insert(state.beta_memories, new_beta_memory)

        join_nodes =
          RefMap.update!(state.join_nodes, parent_ref, fn parent_node = %JoinNode{} ->
            %{parent_node | children: [new_beta_memory_ref | parent_node.children]}
          end)

        state =
          %{state | beta_memories: beta_memories, join_nodes: join_nodes}
          |> update_new_node_with_matches_from_above(new_beta_memory_ref)

        {state, new_beta_memory_ref}
    end
  end

  @spec update_new_node_with_matches_from_above(
          State.t(),
          BetaMemory.ref() | ActivationNode.ref()
        ) :: State.t()
  def update_new_node_with_matches_from_above(
        state,
        new_node_ref
      ) do
    new_node =
      case new_node_ref do
        {:beta_memory_ref, _} ->
          RefMap.fetch!(state.beta_memories, new_node_ref)

        {:activation_node_ref, _} ->
          RefMap.fetch!(state.activation_nodes, new_node_ref)
      end

    parent_ref = {:join_node_ref, _} = new_node.parent
    parent = RefMap.fetch!(state.join_nodes, parent_ref)
    saved_children = parent.children

    {join_nodes, parent} =
      RefMap.update_and_fetch!(state.join_nodes, parent_ref, fn join_node ->
        %{join_node | children: [new_node_ref]}
      end)

    state = %{state | join_nodes: join_nodes}

    alpha_memory_ref = {:alpha_memory_ref, _} = parent.alpha_memory
    alpha_memory = RefMap.fetch!(state.alpha_memories, alpha_memory_ref)

    state =
      Enum.reduce(alpha_memory.facts, state, fn fact, state ->
        JoinNode.right_activate(state, parent_ref, fact)
      end)

    join_nodes =
      RefMap.update!(state.join_nodes, parent_ref, fn join_node ->
        %{join_node | children: saved_children}
      end)

    %{state | join_nodes: join_nodes}
  end

  @spec left_activate(
          State.t(),
          BetaMemory.ref(),
          BetaMemory.partial_activation(),
          Fact.t()
        ) :: State.t()
  def left_activate(
        state = %State{},
        beta_memory_ref = {:beta_memory_ref, _},
        partial_activation,
        fact
      ) do
    new_partial_activation = [fact | partial_activation]

    # add the new partial activation to the given beta memory in the state
    {beta_memories, beta_memory} =
      RefMap.update_and_fetch!(
        state.beta_memories,
        beta_memory_ref,
        fn beta_memory = %BetaMemory{} ->
          %{
            beta_memory
            | partial_activations:
                MapSet.put(beta_memory.partial_activations, new_partial_activation)
          }
        end
      )

    # for each fact in the new partial activation, update that fact's info in the state
    # to remember that this beta memory has a reference to that fact via this new partial activation
    facts =
      Enum.reduce(new_partial_activation, state.facts, fn fact, factmap ->
        Map.update!(factmap, fact, fn fact_info = %FactInfo{} ->
          %{
            fact_info
            | partial_activations:
                MapSet.put(
                  fact_info.partial_activations,
                  {beta_memory_ref, new_partial_activation}
                )
          }
        end)
      end)

    # for each child join node of the beta memory, perform a left activation, and return the final state
    Enum.reduce(
      beta_memory.children,
      %{state | facts: facts, beta_memories: beta_memories},
      fn join_node_ref, state ->
        JoinNode.left_activate(state, join_node_ref, new_partial_activation)
      end
    )
  end
end
