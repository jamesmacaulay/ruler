defmodule Ruler.Condition do
  alias Ruler.{
    FactTemplate
  }

  @type t ::
          {:known, FactTemplate.t()}
          | {:not_known, FactTemplate.t()}

  @spec generate_bindings(Condition.t(), Fact.t()) :: FactTemplate.bindings_map()
  def generate_bindings({:known, template}, fact) do
    FactTemplate.generate_bindings(template, fact)
  end
end
