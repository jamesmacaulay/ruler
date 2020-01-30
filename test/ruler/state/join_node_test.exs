defmodule Ruler.JoinNodeTest do
  use ExUnit.Case
  alias Ruler.JoinNode
  doctest Ruler.JoinNode

  test "Comparison.perform returns true when specified field values are equal" do
    comparison = %JoinNode.Comparison{arg1_field: 2, fact2_index: 0, arg2_field: 2}
    partial_activation = [{"user:99", :id, "99"}]

    comparison_result =
      comparison
      |> JoinNode.Comparison.perform(partial_activation, {"project:1", :owner_id, "99"})

    assert comparison_result == true
  end

  test "Comparison.perform returns false when specified field values are not equal" do
    comparison = %JoinNode.Comparison{arg1_field: 2, fact2_index: 0, arg2_field: 2}
    partial_activation = [{"user:99", :id, "99"}]

    comparison_result =
      comparison
      |> JoinNode.Comparison.perform(partial_activation, {"project:1", :owner_id, "1"})

    assert comparison_result == false
  end
end
