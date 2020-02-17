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

  @type activation_event :: {:activate, Activation.t()} | {:deactivate, Activation.t()}

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

  @spec finalize(t) :: t
  def finalize(ctx) do
    # we've been building up this stack-list backwards
    %{ctx | activation_events: Enum.reverse(ctx.activation_events)}
  end

  @spec perform_activation_effects(t) :: :ok
  def perform_activation_effects(ctx) do
    ctx.activation_events
    |> Enum.each(fn event = {_, activation} ->
      rule = Map.fetch!(ctx.state.rules, activation.rule_id)

      Enum.each(rule.actions, fn
        {:perform_effects, {module, function_name}} ->
          apply(module, function_name, [ctx, event])
          nil
      end)
    end)
  end
end
