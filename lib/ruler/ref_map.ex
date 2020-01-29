# RefMap is an immutable data structure that emulates a bag of mutable references.
# When a new item is inserted into the RefMap, an ID is automatically generated for it.
# This ID is used for subsequent fetches, updates, and removals.
defmodule Ruler.RefMap do
  alias Ruler.RefMap

  @enforce_keys [:tag]
  defstruct [:tag, storage: %{}, unused_keys: []]

  @type index :: non_neg_integer()
  @type ref(tag) :: {tag, index}
  @opaque t(tag, val) :: %__MODULE__{
            tag: tag,
            storage: %{required(RefMap.ref(tag)) => val},
            unused_keys: [RefMap.ref(tag)]
          }

  @spec new(tag) :: RefMap.t(tag, any()) when tag: atom()
  def new(tag) do
    %__MODULE__{tag: tag}
  end

  @spec new(tag, val) :: RefMap.t(tag, val) when tag: atom(), val: var
  def new(tag, item) do
    insert(%__MODULE__{tag: tag}, item)
    |> elem(0)
  end

  @spec keys(RefMap.t(tag, any())) :: [RefMap.ref(tag)] when tag: atom()
  def keys(refmap = %RefMap{}) do
    Map.keys(refmap.storage)
  end

  @spec insert(RefMap.t(tag, val), val) :: {RefMap.t(tag, val), RefMap.ref(tag)}
        when tag: atom(), val: var
  def insert(refmap = %RefMap{}, item) do
    case refmap.unused_keys do
      [] ->
        next_key = {refmap.tag, Kernel.map_size(refmap.storage)}
        {%{refmap | storage: Map.put(refmap.storage, next_key, item)}, next_key}

      [next_key | remaining] ->
        {%{refmap | storage: Map.put(refmap.storage, next_key, item), unused_keys: remaining},
         next_key}
    end
  end

  @spec remove(RefMap.t(tag, val), RefMap.ref(tag)) :: RefMap.t(tag, val)
        when tag: atom(), val: var
  def remove(refmap = %RefMap{}, ref = {tag, index})
      when is_integer(index) and index >= 0 do
    ^tag = refmap.tag
    max_index = Kernel.map_size(refmap.storage) + length(refmap.unused_keys) - 1
    new_storage = Map.delete(refmap.storage, ref)

    case index do
      ^max_index ->
        %{refmap | storage: new_storage}

      _ when index < max_index ->
        %{refmap | storage: new_storage, unused_keys: [ref | refmap.unused_keys]}
    end
  end

  @spec get(RefMap.t(tag, val), RefMap.ref(tag)) :: val | nil when tag: atom(), val: var
  def get(refmap = %RefMap{}, ref = {tag, index})
      when is_integer(index) and index >= 0 do
    ^tag = refmap.tag
    Map.get(refmap.storage, ref)
  end

  @spec fetch!(RefMap.t(tag, val), RefMap.ref(tag)) :: val when tag: atom(), val: var
  def fetch!(refmap = %RefMap{}, ref = {tag, index})
      when is_integer(index) and index >= 0 do
    ^tag = refmap.tag
    Map.fetch!(refmap.storage, ref)
  end

  @spec update!(RefMap.t(tag, val), RefMap.ref(tag), (val -> val)) :: RefMap.t(tag, val)
        when tag: atom(), val: var
  def update!(refmap = %RefMap{}, ref = {tag, index}, fun)
      when is_integer(index) and index >= 0 do
    ^tag = refmap.tag
    %{refmap | storage: Map.update!(refmap.storage, ref, fun)}
  end

  @spec update_and_fetch!(RefMap.t(tag, val), RefMap.ref(tag), (val -> val)) ::
          {RefMap.t(tag, val), val}
        when tag: atom(), val: var
  def update_and_fetch!(refmap = %RefMap{}, ref = {tag, index}, fun)
      when is_integer(index) and index >= 0 do
    ^tag = refmap.tag
    result = fun.(Map.fetch!(refmap.storage, ref))

    {%{
       refmap
       | storage: Map.put(refmap.storage, ref, result)
     }, result}
  end
end
