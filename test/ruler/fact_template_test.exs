defmodule Ruler.FactTemplateTest do
  use ExUnit.Case
  alias Ruler.FactTemplate
  doctest Ruler.FactTemplate

  test "constants_and_nils" do
    template = {{:var, :x}, {:const, :follows}, {:var, :y}}
    assert FactTemplate.constants_and_nils(template) == {nil, {:const, :follows}, nil}
  end

  test "constant_tests" do
    template = {{:var, :x}, {:const, :follows}, {:var, :y}}
    assert FactTemplate.constant_tests(template) == [{1, :follows}]
  end
end
