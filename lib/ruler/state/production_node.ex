defmodule Ruler.State.ProductionNode do
  alias Ruler.{
    State
  }

  @enforce_keys [:rule_id, :activation_nodes]
  defstruct [:rule_id, :activation_nodes]

  @type t :: %__MODULE__{
          rule_id: Rule.id(),
          activation_nodes: [State.ActivationNode.ref()]
        }
  @type ref :: {:production_node_ref, Rule.id()}

  @spec ref_from_rule_id(Rule.id()) :: ref
  def ref_from_rule_id(rule_id) do
    {:production_node_ref, rule_id}
  end

  @spec rule_id_from_ref(ref) :: Rule.id()
  def rule_id_from_ref({:production_node_ref, rule_id}) do
    rule_id
  end
end
