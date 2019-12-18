defmodule Ruler.ActivationNode do
  alias Ruler.{
    Fact,
    RefMap,
    ReteNode,
    Rule
  }

  @enforce_keys [:parent, :children, :rule, :activations]
  defstruct [:parent, :children, :rule, :activations]

  @type activation :: [Fact.t()]
  @type t :: %__MODULE__{
          parent: ReteNode.ref(),
          # empty list type because never any children?
          children: [ReteNode.ref()],
          rule: Rule.id(),
          activations: MapSet.t(activation)
        }
  @type ref :: RefMap.ref()
end
