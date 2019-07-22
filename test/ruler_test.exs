defmodule RulerTest do
  use ExUnit.Case
  doctest Ruler

  test "greets the world" do
    assert Ruler.hello() == :world
  end
end
