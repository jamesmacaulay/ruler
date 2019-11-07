defmodule Ruler.RefMapTest do
  use ExUnit.Case
  alias Ruler.RefMap
  doctest Ruler.RefMap

  test "insertions and removals at various indexes" do
    arena = RefMap.new()
    {arena, 0} = RefMap.insert(arena, :a)
    {arena, 1} = RefMap.insert(arena, :b)
    {arena, 2} = RefMap.insert(arena, :c)
    arena = RefMap.remove(arena, 2)
    {arena, 2} = RefMap.insert(arena, :d)
    arena = RefMap.remove(arena, 1)
    {arena, 1} = RefMap.insert(arena, :e)
    arena = RefMap.remove(arena, 0)
    arena = RefMap.remove(arena, 1)
    {arena, 1} = RefMap.insert(arena, :f)
    {arena, 0} = RefMap.insert(arena, :g)
    {arena, 3} = RefMap.insert(arena, :h)
    arena = RefMap.remove(arena, 1)
    assert for(i <- [0, 1, 2, 3, 4], do: RefMap.get(arena, i)) == [:g, nil, :d, :h, nil]
  end

  test "get existing item" do
    {arena, index} = RefMap.insert(RefMap.new(), :foo)
    assert RefMap.get(arena, index) == :foo
  end

  test "get item that isn't there" do
    assert RefMap.get(RefMap.new(), 0) == nil
  end

  test "remove existing item" do
    {arena, index} = RefMap.insert(RefMap.new(), :foo)
    arena2 = RefMap.remove(arena, index)
    assert RefMap.get(arena2, index) == nil
  end

  test "fetch! existing item" do
    {arena, index} = RefMap.insert(RefMap.new(), :foo)
    assert RefMap.fetch!(arena, index) == :foo
  end

  test "fetch! item that isn't there" do
    assert_raise KeyError, fn ->
      assert RefMap.fetch!(RefMap.new(), 0)
    end
  end

  test "update! existing item with function" do
    {arena, index} = RefMap.insert(RefMap.new(), 100)
    arena = RefMap.update!(arena, index, &(&1 + 1))
    assert RefMap.get(arena, index) == 101
  end

  test "update! item that isn't there" do
    assert_raise KeyError, fn ->
      assert RefMap.update!(RefMap.new(), 0, &(&1 + 1))
    end
  end

  test "update_and_fetch! existing item with function" do
    {arena, index} = RefMap.insert(RefMap.new(), 100)
    {arena, new_value} = RefMap.update_and_fetch!(arena, index, &(&1 + 1))
    assert RefMap.get(arena, index) == 101
    assert new_value == 101
  end

  test "update_and_fetch! item that isn't there" do
    assert_raise KeyError, fn ->
      assert RefMap.update_and_fetch!(RefMap.new(), 0, &(&1 + 1))
    end
  end
end
