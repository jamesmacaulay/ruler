defmodule Ruler.Engine.Dsl do
  defmacro rule(id, do: [{:->, _, [[clauses], actions]}])
           when is_list(clauses) and is_list(actions) do
    converted_clauses = convert_clauses(clauses)

    quote do
      %Ruler.Rule{
        id: unquote(id),
        clauses: unquote(converted_clauses),
        actions: unquote(actions)
      }
    end
  end

  defmacro clauses(ast) when is_list(ast) do
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

  defp convert_clauses(ast) when is_list(ast) do
    Enum.map(ast, &convert_clause/1)
  end

  defp convert_clause(ast = {:{}, _, [_, _, _]}) do
    {:condition, {:known, convert_template(ast)}}
  end

  defp convert_top_level_variables({:^, [], [{symbol, metadata, atom}]}) when is_atom(atom) do
    {symbol, metadata, atom}
  end

  defp convert_top_level_variables({symbol, _, atom}) when is_atom(atom), do: {:var, symbol}
  defp convert_top_level_variables(ast), do: {:const, ast}
end
