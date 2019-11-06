# RefMap is an immutable data structure that emulates a bag of mutable references.
# When a new item is inserted into the RefMap, an ID is automatically generated for it.
# This ID is used for subsequent fetches, updates, and removals.
defmodule Ruler.RefMap do
  defstruct storage: %{}, unused_indexes: []

  @opaque t(a) :: %__MODULE__{
            storage: %{optional(non_neg_integer()) => a},
            unused_indexes: [non_neg_integer()]
          }
  @opaque t :: t(any())

  @spec new :: Ruler.RefMap.t()
  def new do
    %__MODULE__{}
  end

  @spec insert(Ruler.RefMap.t(a), a) :: {Ruler.RefMap.t(a), non_neg_integer} when a: var
  def insert(refmap = %__MODULE__{storage: storage, unused_indexes: unused_indexes}, item) do
    case unused_indexes do
      [] ->
        new_index = Kernel.map_size(storage)
        {%{refmap | storage: Map.put(storage, new_index, item)}, new_index}

      [new_index | remaining] ->
        {%{refmap | storage: Map.put(storage, new_index, item), unused_indexes: remaining},
         new_index}
    end
  end

  @spec remove(Ruler.RefMap.t(a), non_neg_integer) :: Ruler.RefMap.t(a) when a: var
  def remove(refmap = %__MODULE__{storage: storage, unused_indexes: unused_indexes}, index)
      when is_integer(index) and index >= 0 do
    max_index = Kernel.map_size(storage) + length(unused_indexes) - 1
    new_storage = Map.delete(storage, index)

    case index do
      ^max_index ->
        %{refmap | storage: new_storage}

      _ when index < max_index ->
        %{refmap | storage: new_storage, unused_indexes: [index | unused_indexes]}
    end
  end

  @spec get(Ruler.RefMap.t(a), non_neg_integer) :: a | nil when a: var
  def get(_refmap = %__MODULE__{storage: storage}, index)
      when is_integer(index) and index >= 0 do
    Map.get(storage, index)
  end

  @spec fetch!(Ruler.RefMap.t(a), non_neg_integer) :: a when a: var
  def fetch!(_refmap = %__MODULE__{storage: storage}, index)
      when is_integer(index) and index >= 0 do
    Map.fetch!(storage, index)
  end

  @spec update!(Ruler.RefMap.t(a), non_neg_integer, (a -> a)) :: Ruler.RefMap.t(a)
        when a: var
  def update!(refmap = %__MODULE__{storage: storage}, index, fun) do
    %{refmap | storage: Map.update!(storage, index, fun)}
  end
end
