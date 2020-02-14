defmodule Ruler.EventContext do
  alias Ruler.{
    Activation,
    Fact,
    State
  }

  @enforce_keys [:state, :operation]
  defstruct [:state, :operation, activation_events: []]

  @type add_fact :: {:add_fact, Fact.t()}
  @type remove_fact :: {:remove_fact, Fact.t()}
  @type add_rule :: {:add_rule, Rule.t()}
  @type operation :: add_fact | remove_fact | add_rule

  @type add_activation_event :: {:add_activation, Activation.t()}
  @type remove_activation_event :: {:remove_activation, Activation.t()}
  @type activation_event :: add_activation_event | remove_activation_event

  @type t :: %__MODULE__{
          state: State.t(),
          operation: operation,
          activation_events: [activation_event]
        }

  @spec new(State.t(), operation) :: t
  def new(state, operation) do
    %__MODULE__{
      state: state,
      operation: operation
    }
  end
end
