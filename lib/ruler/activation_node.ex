defmodule Ruler.ActivationNode do
  alias Ruler.{
    Activation,
    ActivationNode,
    BetaMemory,
    Condition,
    Fact,
    JoinNode,
    RefMap,
    Rule,
    State
  }

  @enforce_keys [:parent, :rule, :activations]
  defstruct [:parent, :rule, :activations]

  @type t :: %__MODULE__{
          parent: JoinNode.ref(),
          rule: Rule.id(),
          activations: MapSet.t(Activation.t())
        }
  @type ref :: {:activation_node_ref, RefMap.ref()}

  @spec left_activate(
          State.t(),
          ActivationNode.ref(),
          BetaMemory.partial_activation(),
          Fact.t()
        ) :: State.t()
  def left_activate(
        state = %State{},
        {:activation_node_ref, inner_activation_node_ref},
        partial_activation,
        fact
      ) do
    # new_activation = [fact | partial_activation]

    rule_id = RefMap.fetch!(state.activation_nodes, inner_activation_node_ref).rule
    fact_stack = [fact | partial_activation]
    facts = Enum.reverse(fact_stack)
    rule = Map.fetch!(state.rules, rule_id)

    bindings =
      Enum.zip(facts, rule.conditions)
      |> Enum.reduce(%{}, fn {fact, condition}, bindings ->
        Map.merge(bindings, Condition.bindings(condition, fact))
      end)

    new_activation = %Activation{
      rule_id: rule_id,
      facts: facts,
      bindings: bindings
    }

    event = {:add_activation, new_activation}

    activation_nodes =
      RefMap.update!(
        state.activation_nodes,
        inner_activation_node_ref,
        fn activation_node = %ActivationNode{} ->
          %{
            activation_node
            | activations: MapSet.put(activation_node.activations, new_activation)
          }
        end
      )

    %{
      state
      | activation_nodes: activation_nodes,
        latest_activation_events: [event | state.latest_activation_events]
    }
  end
end
