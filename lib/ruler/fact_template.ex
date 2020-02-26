defmodule Ruler.FactTemplate do
  @type variable_name :: atom() | String.t()
  @type variable :: {:var, variable_name}
  @type constant :: {:const, term}

  @type test :: variable | constant

  @type t :: {test, test, test}

  @type bindings_map :: %{required(variable_name()) => any()}

  @spec const?(test) :: boolean
  defp const?({:const, _}), do: true
  defp const?({:var, _}), do: false

  @spec var?(test) :: boolean
  defp var?({:const, _}), do: false
  defp var?({:var, _}), do: true

  @spec nil_if_not_const(test) :: {:const, term} | nil
  defp nil_if_not_const(test) do
    if const?(test) do
      test
    else
      nil
    end
  end

  @spec constants_and_nils(t) ::
          {nil | constant, nil | constant, nil | constant}
  def constants_and_nils({id, attr, val}) do
    {nil_if_not_const(id), nil_if_not_const(attr), nil_if_not_const(val)}
  end

  @spec constant_tests(t) :: [{Fact.field_index(), term()}]
  def constant_tests({id, attr, val}) do
    [{0, id}, {1, attr}, {2, val}]
    |> Enum.filter(fn {_, f} -> const?(f) end)
    |> Enum.map(fn {i, {:const, x}} -> {i, x} end)
  end

  @spec indexed_variables(t) :: [{Fact.field_index(), variable_name()}]
  def indexed_variables({id, attr, val}) do
    [{0, id}, {1, attr}, {2, val}]
    |> Enum.filter(fn {_, f} -> var?(f) end)
    |> Enum.map(fn {i, {:var, x}} -> {i, x} end)
  end

  @spec constant_tests_match_fact?(t, Fact.t()) :: boolean
  def constant_tests_match_fact?(template, fact) do
    constant_tests(template)
    |> Enum.all?(fn {field_index, constant_value} ->
      elem(fact, field_index) == constant_value
    end)
  end

  @spec generate_bindings(FactTemplate.t(), Fact.t()) :: bindings_map
  def generate_bindings(template, fact) do
    indexed_variables(template)
    |> Enum.reduce(%{}, fn {field_index, variable_name}, binding_map ->
      Map.put(binding_map, variable_name, elem(fact, field_index))
    end)
  end

  @spec apply_bindings(FactTemplate.t(), bindings_map) :: Fact.t()
  def apply_bindings({id, attr, val}, bindings) do
    {
      apply_bindings_to_field(id, bindings),
      apply_bindings_to_field(attr, bindings),
      apply_bindings_to_field(val, bindings)
    }
  end

  defp apply_bindings_to_field({:const, value}, _), do: value
  defp apply_bindings_to_field({:var, name}, bindings), do: Map.fetch!(bindings, name)
end
