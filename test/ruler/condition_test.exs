defmodule Ruler.ConditionTest do
  use ExUnit.Case
  alias Ruler.Condition
  doctest Ruler.Condition

  test "constants_and_nils" do
    condition = {{:var, :x}, {:const, :follows}, {:var, :y}}
    assert Condition.constants_and_nils(condition) == {nil, {:const, :follows}, nil}
  end

  test "constant_tests" do
    condition = {{:var, :x}, {:const, :follows}, {:var, :y}}
    assert Condition.constant_tests(condition) == [{1, :follows}]
  end
end
