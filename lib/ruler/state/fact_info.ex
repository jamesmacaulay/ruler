defmodule Ruler.State.FactInfo do
  alias Ruler.{
    Activation
  }

  @enforce_keys [:sources]
  defstruct [:sources]

  # :explicit_assertion means the fact was added explicitly with an add_fact operation
  # {:implied_by, activation} means that the given activation specifies an implication of this fact via an :imply action
  @type source ::
          :explicit_assertion
          | {:implied_by, Activation.t()}

  @type t :: %__MODULE__{
          sources: MapSet.t(source)
        }

  @spec new(source) :: t
  def new(source) do
    %__MODULE__{
      sources: MapSet.new([source])
    }
  end

  @spec add_source(t, source) :: t
  def add_source(fact_info, source) do
    %{fact_info | sources: MapSet.put(fact_info.sources, source)}
  end

  @spec remove_source(t, source) :: t
  def remove_source(fact_info, source) do
    %{fact_info | sources: MapSet.delete(fact_info.sources, source)}
  end

  @spec baseless?(t) :: boolean
  def baseless?(fact_info) do
    MapSet.size(fact_info.sources) == 0
  end
end
