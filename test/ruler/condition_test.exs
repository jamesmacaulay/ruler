defmodule Ruler.ConditionTest do
  use ExUnit.Case
  alias Ruler.Condition
  doctest Ruler.Condition

  test "constants" do
    condition = {{:var, :x}, {:const, :follows}, {:var, :y}}
    assert Condition.constants(condition) == {nil, {:const, :follows}, nil}
  end
end
