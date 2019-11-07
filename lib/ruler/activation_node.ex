defmodule Ruler.ActivationNode do
  @enforce_keys [:parent, :children, :rule, :activations]
  defstruct [:parent, :children, :rule, :activations]

  @type activation :: [Ruler.Fact.t()]
  @type t :: %__MODULE__{
          parent: Ruler.RefMap.ref(),
          children: [Ruler.RefMap.ref()],
          rule: Ruler.Rule.id(),
          activations: MapSet.t(activation)
        }
end
