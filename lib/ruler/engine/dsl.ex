defmodule Ruler.Engine.Dsl do
  defmacro rule(id, do: [{:->, _, [[conditions], actions]}])
           when is_list(conditions) and is_list(actions) do
    converted_conditions = convert_conditions(conditions)

    quote do
      %Ruler.Rule{
        id: unquote(id),
        conditions: unquote(converted_conditions),
        actions: unquote(actions)
      }
    end
  end

  defmacro conditions(ast) when is_list(ast) do
    convert_conditions(ast)
  end

  defmacro imply(ast = {:{}, _, [_, _, _]}) do
    {:imply, convert_template(ast)}
  end

  defmacro template(ast = {:{}, _, [_, _, _]}) do
    convert_template(ast)
  end

  defp convert_template({:{}, metadata, elements = [_, _, _]}) do
    {:{}, metadata, Enum.map(elements, &convert_top_level_variables/1)}
  end

  defp convert_conditions(ast) when is_list(ast) do
    Enum.map(ast, &convert_condition/1)
  end

  defp convert_condition(ast = {:{}, _, [_, _, _]}) do
    {:known, convert_template(ast)}
  end

  defp convert_top_level_variables({:^, [], [{symbol, metadata, atom}]}) when is_atom(atom) do
    {symbol, metadata, atom}
  end

  defp convert_top_level_variables({symbol, _, atom}) when is_atom(atom), do: {:var, symbol}
  defp convert_top_level_variables(ast), do: {:const, ast}
end
