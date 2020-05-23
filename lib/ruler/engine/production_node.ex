defmodule Ruler.Engine.ProductionNode do
  alias Ruler.{
    Engine,
    State
  }

  @type state :: State.t()
  @type engine :: Engine.t()
  @type node_data :: State.ProductionNode.t()
  @type ref :: State.ProductionNode.ref()
  @type rule :: Rule.t()

  @spec fetch!(state, ref) :: node_data
  def fetch!(state, ref) do
    Map.fetch!(state.production_nodes, ref)
  end

  @spec fetch_with_rule_id!(state, Rule.id()) :: node_data
  def fetch_with_rule_id!(state, rule_id) do
    fetch!(state, State.ProductionNode.ref_from_rule_id(rule_id))
  end

  @spec build(engine, rule) :: engine
  def build(engine, rule) do
    {engine, refs} = Engine.ActivationNode.build_all(engine, rule)

    {engine, _} =
      insert(engine, %State.ProductionNode{
        rule_id: rule.id,
        activation_nodes: refs
      })

    engine
  end

  @spec insert(engine, node_data) :: {engine, ref}
  def insert(engine, node_data) do
    state = engine.state
    ref = State.ProductionNode.ref_from_rule_id(node_data.rule_id)
    nodes = Map.put(state.production_nodes, ref, node_data)
    state = %{state | production_nodes: nodes}
    {%{engine | state: state}, ref}
  end
end
