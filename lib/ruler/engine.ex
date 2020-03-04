defmodule Ruler.Engine do
  alias Ruler.{
    Action,
    Activation,
    FactTemplate,
    Engine,
    Fact,
    Rule,
    State
  }

  @type state :: State.t()
  @type fact :: Fact.t()
  @type rule :: Rule.t()

  @type instruction ::
          {:add_fact, fact}
          | {:remove_fact, fact}
          | {:add_rule, rule}

  @type action :: Action.t()
  @type activation :: Activation.t()
  @type activation_event :: State.activation_event()

  @type log_event ::
          {:instruction, instruction}
          | {:add_fact_source, fact, State.FactInfo.source()}
          | {:remove_fact_source, fact, State.FactInfo.source()}
          | {:fact_was_added, fact}
          | {:fact_was_removed, fact}
          | {:activation_event, activation_event}

  @enforce_keys [:state]
  defstruct [:state, instruction_queue: :queue.new(), log: []]

  @type t :: %__MODULE__{
          state: state,
          instruction_queue: :queue.queue(instruction),
          log: [log_event]
        }

  @spec new() :: t
  def new() do
    %__MODULE__{
      state: State.new()
    }
  end

  @spec add_instructions(t, [instruction]) :: t
  def add_instructions(engine, instructions) do
    instruction_queue = :queue.join(engine.instruction_queue, :queue.from_list(instructions))

    %{engine | instruction_queue: instruction_queue}
  end

  @spec add_instruction(t, instruction) :: t
  def add_instruction(engine, instruction) do
    %{engine | instruction_queue: :queue.in(instruction, engine.instruction_queue)}
  end

  @spec add_log_event(t, log_event) :: t
  def add_log_event(engine, log_event) do
    %{engine | log: [log_event | engine.log]}
  end

  @spec done?(t) :: boolean
  def done?(engine) do
    :queue.is_empty(engine.instruction_queue) &&
      MapSet.equal?(engine.state.proposed_activations, engine.state.committed_activations)
  end

  @spec choose_from_conflict_set(t) :: activation_event | nil
  def choose_from_conflict_set(engine) do
    # TODO use a better conflict resolution strategy!
    engine.state
    |> State.conflict_set()
    |> MapSet.to_list()
    |> List.first()
  end

  @spec step(t) :: {:ok, t} | :done
  def step(engine) do
    if length(engine.log) > 100, do: raise(engine)

    case choose_from_conflict_set(engine) do
      nil ->
        process_next_instruction_from_queue(engine)

      activation_event ->
        engine =
          add_log_event(engine, {:activation_event, activation_event})
          |> process_activation_event(activation_event)

        {:ok, engine}
    end
  end

  @spec run_until_done(t) :: t
  def run_until_done(engine) do
    case step(engine) do
      :done ->
        engine

      {:ok, engine} ->
        run_until_done(engine)
    end
  end

  @spec process_next_instruction_from_queue(t) :: {:ok, t} | :done
  def process_next_instruction_from_queue(engine) do
    case :queue.out(engine.instruction_queue) do
      {:empty, _} ->
        :done

      {{:value, instruction}, rest_of_queue} ->
        engine =
          add_log_event(engine, {:instruction, instruction})
          |> process_instruction(instruction)

        {:ok, %{engine | instruction_queue: rest_of_queue}}
    end
  end

  @spec process_instruction(t, instruction) :: t
  def process_instruction(engine, {:add_rule, rule}) do
    state = engine.state

    %{engine | state: %{state | rules: Map.put(state.rules, rule.id, rule)}}
    |> Engine.ActivationNode.build(rule)
  end

  def process_instruction(engine, {:add_fact, fact}) do
    Engine.FactInfo.add_fact_source(engine, fact, :explicit_assertion)
  end

  def process_instruction(engine, {:remove_fact, fact}) do
    Engine.FactInfo.remove_fact_source(engine, fact, :explicit_assertion)
  end

  @spec actions_for_activation(t, activation) :: [Action.t()]
  defp actions_for_activation(engine, activation) do
    Map.fetch!(engine.state.rules, activation.rule_id).actions
  end

  @spec process_activation_event(t, activation_event) :: t
  def process_activation_event(engine, event = {tag, activation}) do
    engine = commit_activation_event(engine, event)

    Enum.reduce(actions_for_activation(engine, activation), engine, fn
      {:perform_effects, {module, function_name}}, engine ->
        apply(module, function_name, [engine, event])
        engine

      {:imply, template}, engine ->
        fact = FactTemplate.apply_bindings(template, activation.bindings)

        case tag do
          :activate ->
            Engine.FactInfo.add_fact_source(engine, fact, {:implied_by, activation})

          :deactivate ->
            Engine.FactInfo.remove_fact_source(engine, fact, {:implied_by, activation})
        end
    end)
  end

  @spec commit_activation_event(t, activation_event) :: t
  def commit_activation_event(engine, {:activate, activation}) do
    committed_activations = MapSet.put(engine.state.committed_activations, activation)
    %{engine | state: %{engine.state | committed_activations: committed_activations}}
  end

  def commit_activation_event(engine, {:deactivate, activation}) do
    committed_activations = MapSet.delete(engine.state.committed_activations, activation)
    %{engine | state: %{engine.state | committed_activations: committed_activations}}
  end

  @spec add_facts(t, [fact]) :: t
  def add_facts(engine, facts) do
    engine
    |> add_instructions(Enum.map(facts, &{:add_fact, &1}))
    |> run_until_done()
  end

  @spec remove_facts(t, [fact]) :: t
  def remove_facts(engine, facts) do
    engine
    |> add_instructions(Enum.map(facts, &{:remove_fact, &1}))
    |> run_until_done()
  end

  @spec add_rules(t, [rule]) :: t
  def add_rules(engine, rules) do
    engine
    |> add_instructions(Enum.map(rules, &{:add_rule, &1}))
    |> run_until_done()
  end

  @spec query(t, [Condition.t()]) :: MapSet.t(Activation.t())
  def query(engine, conditions) do
    temp_engine =
      add_rules(engine, [
        %Rule{
          id: {Ruler.Engine, :query},
          conditions: conditions,
          actions: []
        }
      ])

    MapSet.difference(temp_engine.state.committed_activations, engine.state.committed_activations)
  end
end
