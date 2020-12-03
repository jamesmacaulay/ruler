defmodule Ruler.Engine.NodeView do
  alias Ruler.{Engine, State}

  @enforce_keys [:engine, :ref]
  defstruct [:engine, :ref]

  @type ref ::
          State.ActivationNode.ref()
          | State.AlphaMemory.ref()
          | State.BetaMemory.ref()
          | State.ConstantTestNode.ref()
          | State.JoinNode.ref()
          | State.NegativeNode.ref()
          | State.ProductionNode.ref()

  @type node_state ::
          State.ActivationNode.t()
          | State.AlphaMemory.t()
          | State.BetaMemory.t()
          | State.ConstantTestNode.t()
          | State.JoinNode.t()
          | State.NegativeNode.t()
          | State.ProductionNode.t()

  @type t :: %Engine.NodeView{
          engine: Engine.t(),
          ref: ref
        }

  @spec new(Engine.t(), ref) :: Engine.NodeView.t()
  def new(engine, ref) do
    %Engine.NodeView{engine: engine, ref: ref}
  end

  @spec fetch_state(t) :: node_state
  def fetch_state(%Engine.NodeView{engine: engine, ref: ref = {tag, _}}) do
    state = engine.state

    case tag do
      :activation_node_ref -> Engine.ActivationNode.fetch!(state, ref)
      :alpha_memory_ref -> Engine.AlphaMemory.fetch!(state, ref)
      :beta_memory_ref -> Engine.BetaMemory.fetch!(state, ref)
      :constant_test_node_ref -> Engine.ConstantTestNode.fetch!(state, ref)
      :join_node_ref -> Engine.JoinNode.fetch!(state, ref)
      :negative_node_ref -> Engine.NegativeNode.fetch!(state, ref)
      :production_node_ref -> Engine.ProductionNode.fetch!(state, ref)
    end
  end

  @spec all(Engine.t()) :: [Engine.NodeView.t()]
  def all(engine) do
    all_refs(engine)
    |> Enum.map(&new(engine, &1))
  end

  @spec all_refs(Engine.t()) :: [ref]
  def all_refs(engine) do
    state = engine.state

    [
      state.constant_test_nodes.storage,
      state.alpha_memories.storage,
      state.beta_memories.storage,
      state.join_nodes.storage,
      state.negative_nodes.storage,
      state.activation_nodes.storage,
      state.production_nodes
    ]
    |> Enum.reduce(&Map.merge/2)
    |> Map.keys()
  end

  @spec links(t) :: map()
  def links(view = %Engine.NodeView{engine: engine, ref: {tag, _}}) do
    state = fetch_state(view)

    case tag do
      :activation_node_ref ->
        %{parent: new(engine, state.parent_ref)}

      :alpha_memory_ref ->
        %{beta_nodes: Enum.map(state.beta_node_refs, &new(engine, &1))}

      :beta_memory_ref ->
        %{
          parent: if(state.parent_ref == nil, do: nil, else: new(engine, state.parent_ref)),
          children: Enum.map(state.child_refs, &new(engine, &1))
        }

      :constant_test_node_ref ->
        %{
          alpha_memory:
            if(state.alpha_memory_ref == nil, do: nil, else: new(engine, state.alpha_memory_ref)),
          children: Enum.map(state.child_refs, &new(engine, &1))
        }

      :join_node_ref ->
        %{
          alpha_memory: new(engine, state.alpha_memory_ref),
          parent: new(engine, state.parent_ref),
          children: Enum.map(state.child_refs, &new(engine, &1))
        }

      :negative_node_ref ->
        %{
          alpha_memory: new(engine, state.alpha_memory_ref),
          parent: if(state.parent_ref == nil, do: nil, else: new(engine, state.parent_ref)),
          children: Enum.map(state.child_refs, &new(engine, &1))
        }

      :production_node_ref ->
        %{
          activation_nodes: Enum.map(state.activation_nodes, &new(engine, &1))
        }
    end
  end

  def parent(view) do
    links(view) |> Map.get(:parent)
  end

  def children(view) do
    links(view) |> Map.get(:children)
  end

  def child(view, index) do
    children(view) |> Enum.at(index)
  end

  def join_nodes(view) do
    links(view) |> Map.get(:join_nodes)
  end

  def join_node(view, index) do
    join_nodes(view) |> Enum.at(index)
  end

  def alpha_memory(view) do
    links(view) |> Map.get(:alpha_memory)
  end

  @spec top_beta(Engine.t()) :: Engine.NodeView.t()
  def top_beta(engine) do
    new(engine, State.BetaMemory.top_node_ref())
  end

  @spec top_alpha(Engine.t()) :: Engine.NodeView.t()
  def top_alpha(engine) do
    new(engine, State.ConstantTestNode.top_node_ref())
  end

  defimpl Inspect, for: Engine.NodeView do
    import Inspect.Algebra

    def inspect(view, opts) do
      concat(["#Ruler.Engine.NodeView<", to_doc(Engine.NodeView.fetch_state(view), opts), ">"])
    end
  end
end
