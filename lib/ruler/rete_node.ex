defmodule Ruler.ReteNode do
  alias Ruler.{
    ActivationNode,
    BetaMemory,
    JoinNode,
    RefMap
  }

  # TODO: maybe change this to a protocol
  @type t :: BetaMemory.t() | JoinNode.t() | ActivationNode.t()
  @type ref :: RefMap.ref()
end
