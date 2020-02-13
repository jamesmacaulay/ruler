defmodule Ruler.State.ActivationNode do
  alias Ruler.{
    Activation,
    State
  }

  @enforce_keys [:parent_ref, :rule_id, :activations]
  defstruct [:parent_ref, :rule_id, :activations]

  @type t :: %__MODULE__{
          parent_ref: State.JoinNode.ref(),
          rule_id: Rule.id(),
          activations: MapSet.t(Activation.t())
        }
  @type ref :: {:activation_node_ref, Rule.id()}

  @spec ref_from_rule_id(Rule.id()) :: ref
  def ref_from_rule_id(rule_id) do
    {:activation_node_ref, rule_id}
  end

  @spec rule_id_from_ref(ref) :: Rule.id()
  def rule_id_from_ref({:activation_node_ref, rule_id}) do
    rule_id
  end
end
