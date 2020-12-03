defmodule Ruler.Engine.Dsl do
  defmacro rule(id, do: [{:->, _, [[clauses], actions]}])
           when is_list(actions) do
    converted_clauses = convert_clauses(clauses)

    quote do
      %Ruler.Rule{
        id: unquote(id),
        clauses: unquote(converted_clauses),
        actions: unquote(actions)
      }
    end
  end

  defmacro clauses(ast) do
    convert_clauses(ast)
  end

  defmacro imply(ast = {:{}, _, [_, _, _]}) do
    {:imply, convert_template(ast)}
  end

  defmacro template(ast = {:{}, _, [_, _, _]}) do
    convert_template(ast)
  end

  defmacro query(engine, do: body = [{:->, _, [[lhs], _]}]) do
    converted_clauses = convert_clauses(lhs)

    quote do
      unquote(engine)
      |> Ruler.Engine.query(unquote(converted_clauses))
      |> Stream.map(fn activation ->
        case activation.facts do
          unquote(body)
        end
      end)
      |> MapSet.new()
    end
  end

  defp convert_template({:{}, metadata, elements = [_, _, _]}) do
    {:{}, metadata, Enum.map(elements, &convert_top_level_variables/1)}
  end

  defp convert_clauses({:not, _, clause_ast}) do
    {:not, convert_clauses(clause_ast)}
  end

  defp convert_clauses(ast = {:|, _, [_, _]}) do
    {:any, listify_disjunction(ast)}
  end

  defp convert_clauses(ast) when is_list(ast) do
    {:all, Enum.map(ast, &convert_clauses/1)}
  end

  defp convert_clauses(ast) do
    {:condition, convert_condition(ast)}
  end

  defp listify_disjunction({:|, _, [lhs, rhs]}) do
    [convert_clauses(lhs) | listify_disjunction(rhs)]
  end

  defp listify_disjunction(ast) do
    [convert_clauses(ast)]
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
