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

  @spec run_with_effects(State.t(), operation, (t -> t)) :: t
  def run_with_effects(state, operation, process_func) do
    new(state, operation)
    |> process_func.()
    |> finalize_with_effects()
  end

  @spec run_without_effects(State.t(), operation, (t -> t)) :: t
  def run_without_effects(state, operation, process_func) do
    new(state, operation)
    |> process_func.()
    |> finalize_without_effects()
  end

  @spec new(State.t(), operation) :: t
  defp new(state, operation) do
    %__MODULE__{
      state: state,
      operation: operation
    }
  end

  @spec finalize_without_effects(t) :: t
  defp finalize_without_effects(ctx) do
    %{
      ctx
      | # we've been building up these stack-lists backwards
        activation_events: Enum.reverse(ctx.activation_events)
    }
  end

  @spec finalize_with_effects(t) :: t
  defp finalize_with_effects(ctx) do
    ctx = finalize_without_effects(ctx)

    perform_activation_effects(ctx)
    ctx
  end

  @spec actions_for_activation(t, Activation.t()) :: [Action.t()]
  defp actions_for_activation(ctx, activation) do
    Map.fetch!(ctx.state.rules, activation.rule_id).actions
  end

  @spec perform_activation_effects(t) :: :ok
  defp perform_activation_effects(ctx) do
    ctx.activation_events
    |> Enum.each(fn event = {_, activation} ->
      Enum.each(actions_for_activation(ctx, activation), fn
        {:perform_effects, {module, function_name}} ->
          apply(module, function_name, [ctx, event])
          nil

        _ ->
          nil
      end)
    end)
  end
end
