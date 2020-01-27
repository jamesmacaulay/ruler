defmodule Ruler.State do
  alias Ruler.{
    Activation,
    ActivationNode,
    AlphaMemory,
    BetaMemory,
    ConstantTestNode,
    Fact,
    FactInfo,
    JoinNode,
    RefMap,
    Rule,
    State
  }

  defstruct facts: %{},
            rules: %{},
            constant_test_nodes:
              RefMap.new(%ConstantTestNode{
                field: nil,
                target_value: nil,
                alpha_memory: nil,
                children: []
              }),
            alpha_memories: RefMap.new(),
            beta_memories:
              RefMap.new(%BetaMemory{
                parent: nil,
                children: MapSet.new(),
                partial_activations: MapSet.new([[]])
              }),
            join_nodes: RefMap.new(),
            activation_nodes: RefMap.new(),
            alpha_top_node: {:constant_test_node_ref, 0},
            beta_top_node: {:beta_memory_ref, 0},
            latest_activation_events: []

  @type t :: %__MODULE__{
          facts: %{Fact.t() => FactInfo.t()},
          rules: %{Rule.id() => Rule.t()},
          constant_test_nodes: RefMap.t(ConstantTestNode.t()),
          alpha_memories: RefMap.t(AlphaMemory.t()),
          beta_memories: RefMap.t(BetaMemory.t()),
          join_nodes: RefMap.t(JoinNode.t()),
          activation_nodes: RefMap.t(ActivationNode.t()),
          alpha_top_node: ConstantTestNode.ref(),
          beta_top_node: BetaMemory.ref(),
          latest_activation_events: [Activation.activation_event()]
        }

  @spec new :: State.t()
  def new do
    %State{}
  end

  @spec add_fact(State.t(), Fact.t()) :: State.t()
  def add_fact(state = %State{}, fact) do
    facts = Map.put(state.facts, fact, FactInfo.new())

    %{state | facts: facts}
    |> ConstantTestNode.activate(state.alpha_top_node, fact)
  end

  @spec remove_fact(State.t(), Fact.t()) :: State.t()
  def remove_fact(state = %State{}, fact) do
    %{state | facts: Map.delete(state.facts, fact)}
  end

  @spec has_fact?(State.t(), Fact.t()) :: boolean
  def has_fact?(state = %State{}, fact) do
    Map.has_key?(state.facts, fact)
  end

  @spec add_rule(State.t(), Rule.t()) :: State.t()
  def add_rule(state = %State{}, rule) do
    state = %{state | rules: Map.put(state.rules, rule.id, rule)}
    [first_condition | rest_conditions] = rule.conditions
    current_beta_memory_ref = state.beta_top_node
    earlier_conditions = []
    comparisons = JoinNode.comparisons_from_condition(first_condition, earlier_conditions)
    {state, alpha_memory_ref} = AlphaMemory.build_or_share(state, first_condition)

    {state, current_join_node_ref} =
      JoinNode.build_or_share(state, current_beta_memory_ref, alpha_memory_ref, comparisons)

    {state, current_join_node_ref = {:join_node_ref, inner_current_join_node_ref},
     _earlier_conditions} =
      Enum.reduce(
        rest_conditions,
        {state, current_join_node_ref, [first_condition]},
        fn condition, {state, current_join_node_ref, earlier_conditions} ->
          {state, current_beta_memory_ref} =
            BetaMemory.build_or_share(state, current_join_node_ref)

          comparisons = JoinNode.comparisons_from_condition(condition, earlier_conditions)
          {state, alpha_memory_ref} = AlphaMemory.build_or_share(state, condition)

          {state, current_join_node_ref} =
            JoinNode.build_or_share(state, current_beta_memory_ref, alpha_memory_ref, comparisons)

          {state, current_join_node_ref, [condition | earlier_conditions]}
        end
      )

    activation_node = %ActivationNode{
      parent: current_join_node_ref,
      rule: rule.id,
      activations: MapSet.new()
    }

    {activation_nodes, inner_activation_node_ref} =
      RefMap.insert(state.activation_nodes, activation_node)

    activation_node_ref = {:activation_node_ref, inner_activation_node_ref}

    state = %{state | activation_nodes: activation_nodes}

    join_nodes =
      RefMap.update!(state.join_nodes, inner_current_join_node_ref, fn join_node ->
        %{join_node | children: [activation_node_ref | join_node.children]}
      end)

    state = %{state | join_nodes: join_nodes}

    BetaMemory.update_new_node_with_matches_from_above(state, activation_node_ref)
  end

  @spec has_rule?(State.t(), Rule.id()) :: boolean
  def has_rule?(state = %State{}, id) do
    Map.has_key?(state.rules, id)
  end
end
