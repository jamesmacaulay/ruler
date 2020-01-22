defmodule Ruler.ActivationNode do
  alias Ruler.{
    ActivationNode,
    BetaMemory,
    Fact,
    JoinNode,
    RefMap,
    Rule,
    State
  }

  @enforce_keys [:parent, :rule, :activations]
  defstruct [:parent, :rule, :activations]

  @type activation :: [Fact.t()]
  @type t :: %__MODULE__{
          parent: JoinNode.ref(),
          rule: Rule.id(),
          activations: MapSet.t(activation)
        }
  @type ref :: RefMap.ref()

  @spec left_activate(
          State.t(),
          ActivationNode.ref(),
          BetaMemory.partial_activation(),
          Fact.t()
        ) :: State.t()
  def left_activate(state = %State{}, activation_node_ref, partial_activation, fact) do
    new_activation = [fact | partial_activation]
    activation_node = %ActivationNode{} = RefMap.fetch!(state.refs, activation_node_ref)

    refs =
      RefMap.update!(
        state.refs,
        activation_node_ref,
        fn activation_node = %ActivationNode{} ->
          %{
            activation_node
            | activations: MapSet.put(activation_node.activations, new_activation)
          }
        end
      )

    %{state | refs: refs}
  end
end
