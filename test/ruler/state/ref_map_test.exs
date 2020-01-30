defmodule Ruler.State.RefMapTest do
  use ExUnit.Case
  alias Ruler.State.RefMap
  doctest Ruler.State.RefMap

  test "insertions and removals at various indexes" do
    refmap = RefMap.new(:some_tag)
    {refmap, {:some_tag, 0}} = RefMap.insert(refmap, :a)
    {refmap, {:some_tag, 1}} = RefMap.insert(refmap, :b)
    {refmap, {:some_tag, 2}} = RefMap.insert(refmap, :c)
    refmap = RefMap.remove(refmap, {:some_tag, 2})
    {refmap, {:some_tag, 2}} = RefMap.insert(refmap, :d)
    refmap = RefMap.remove(refmap, {:some_tag, 1})
    {refmap, {:some_tag, 1}} = RefMap.insert(refmap, :e)
    refmap = RefMap.remove(refmap, {:some_tag, 0})
    refmap = RefMap.remove(refmap, {:some_tag, 1})
    {refmap, {:some_tag, 1}} = RefMap.insert(refmap, :f)
    {refmap, {:some_tag, 0}} = RefMap.insert(refmap, :g)
    {refmap, {:some_tag, 3}} = RefMap.insert(refmap, :h)
    refmap = RefMap.remove(refmap, {:some_tag, 1})

    assert for(
             i <- [0, 1, 2, 3, 4],
             do: RefMap.get(refmap, {:some_tag, i})
           ) == [:g, nil, :d, :h, nil]
  end

  test "get existing item" do
    refmap = RefMap.new(:some_tag)
    {refmap, ref} = RefMap.insert(refmap, :foo)
    assert RefMap.get(refmap, ref) == :foo
  end

  test "get item that isn't there" do
    assert RefMap.get(RefMap.new(:some_tag), {:some_tag, 0}) == nil
  end

  test "get with invalidly tagged ref" do
    assert_raise MatchError, fn ->
      RefMap.get(RefMap.new(:some_tag), {:invalid_tag, 0})
    end
  end

  test "list keys" do
    refmap = RefMap.new(:some_tag)
    {refmap, a_ref} = RefMap.insert(refmap, :a)
    {refmap, b_ref} = RefMap.insert(refmap, :b)
    {refmap, c_ref} = RefMap.insert(refmap, :c)
    refmap = RefMap.remove(refmap, b_ref)

    assert RefMap.keys(refmap) == [a_ref, c_ref]
  end

  test "remove existing item" do
    {refmap, ref} = RefMap.insert(RefMap.new(:some_tag), :foo)
    refmap = RefMap.remove(refmap, ref)
    assert RefMap.get(refmap, ref) == nil
  end

  test "remove with invalidly tagged ref" do
    assert_raise MatchError, fn ->
      RefMap.remove(RefMap.new(:some_tag), {:invalid_tag, 0})
    end
  end

  test "fetch! existing item" do
    {refmap, ref} = RefMap.insert(RefMap.new(:some_tag), :foo)
    assert RefMap.fetch!(refmap, ref) == :foo
  end

  test "fetch! item that isn't there" do
    assert_raise KeyError, fn ->
      assert RefMap.fetch!(RefMap.new(:some_tag), {:some_tag, 0})
    end
  end

  test "fetch! with invalidly tagged ref" do
    assert_raise MatchError, fn ->
      RefMap.fetch!(RefMap.new(:some_tag), {:invalid_tag, 0})
    end
  end

  test "update! existing item with function" do
    {refmap, ref} = RefMap.insert(RefMap.new(:some_tag), 100)
    refmap = RefMap.update!(refmap, ref, &(&1 + 1))
    assert RefMap.get(refmap, ref) == 101
  end

  test "update! item that isn't there" do
    assert_raise KeyError, fn ->
      assert RefMap.update!(RefMap.new(:some_tag), {:some_tag, 0}, &(&1 + 1))
    end
  end

  test "update! with invalidly tagged ref" do
    assert_raise MatchError, fn ->
      RefMap.update!(RefMap.new(:some_tag), {:invalid_tag, 0}, &(&1 + 1))
    end
  end

  test "update_and_fetch! existing item with function" do
    {refmap, ref} = RefMap.insert(RefMap.new(:some_tag), 100)
    {refmap, new_value} = RefMap.update_and_fetch!(refmap, ref, &(&1 + 1))
    assert RefMap.get(refmap, ref) == 101
    assert new_value == 101
  end

  test "update_and_fetch! item that isn't there" do
    assert_raise KeyError, fn ->
      assert RefMap.update_and_fetch!(RefMap.new(:some_tag), {:some_tag, 0}, &(&1 + 1))
    end
  end

  test "update_and_fetch! with invalidly tagged ref" do
    assert_raise MatchError, fn ->
      RefMap.update_and_fetch!(RefMap.new(:some_tag), {:invalid_tag, 0}, &(&1 + 1))
    end
  end
end
