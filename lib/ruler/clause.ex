defmodule Ruler.Clause do
  alias Ruler.{
    Condition
  }

  @type t ::
          {:condition, Condition.t()}
          | {:any, nonempty_list(t)}
          | {:all, [t]}
          | {:not, t}

  # The following function returns a list of lists of conditions.
  # Each inner list represents a conjunction of conditions.
  # The whole list-of-lists represents a normalized disjunction ("any") of those conjunctions ("all").
  # Each list of conditions in the disjunction will be associated with a particular activation node.
  #
  # For example, consider the following clause:
  #
  # {:all,
  #  [
  #    {:any,
  #     [
  #       {:condition, {:known, {{:var, :x}, {:const, :a}, {:const, 0}}},
  #       {:condition, {:known, {{:var, :x}, {:const, :a}, {:const, 1}}}
  #     ]},
  #    {:any,
  #     [
  #       {:condition, {:known, {{:var, :x}, {:const, :b}, {:const, 0}}},
  #       {:condition, {:known, {{:var, :x}, {:const, :b}, {:const, 1}}}
  #     ]}
  #  ]}
  #
  # This can be read as "({x, :a, 0} OR {x, :a, 1}) AND ({x, :b, 0} OR {x, :b, 1})".
  # We want each combination of possibilities in the disjunctions to be activated separately,
  # so that we can be explicit in the activation context about which specific conditions matched.
  # Therefore we normalize the conjunction of disjunctions into a disjunction of conjuctions:
  #
  # [
  #   [
  #     {:known, {{:var, :x}, {:const, :a}, {:const, 0}},
  #     {:known, {{:var, :x}, {:const, :b}, {:const, 0}}
  #   ],
  #   [
  #     {:known, {{:var, :x}, {:const, :a}, {:const, 0}},
  #     {:known, {{:var, :x}, {:const, :b}, {:const, 1}}
  #   ],
  #   [
  #     {:known, {{:var, :x}, {:const, :a}, {:const, 1}},
  #     {:known, {{:var, :x}, {:const, :b}, {:const, 0}}
  #   ],
  #   [
  #     {:known, {{:var, :x}, {:const, :a}, {:const, 1}},
  #     {:known, {{:var, :x}, {:const, :b}, {:const, 1}}
  #   ],
  # ]
  #
  # ...and then each conjunction of conditions will be assigned to a separate activation node.
  # If no :any clauses are used, the returned list will contain a single list of conditions
  # to be used a single activation node,
  @spec condition_matrix_from_clause(t) :: [[Condition.t()]]
  def condition_matrix_from_clause(clause) do
    reversed_condition_matrix_from_clause(clause)
    |> Enum.map(&Enum.reverse/1)
  end

  @spec reversed_condition_matrix_from_clause(t) :: [[Condition.t()]]
  defp reversed_condition_matrix_from_clause({:condition, condition}) do
    [[condition]]
  end

  defp reversed_condition_matrix_from_clause({:any, clauses}) do
    Enum.flat_map(clauses, &reversed_condition_matrix_from_clause/1)
  end

  defp reversed_condition_matrix_from_clause({:all, clauses}) do
    Enum.reduce(clauses, [[]], fn clause, acc ->
      next = reversed_condition_matrix_from_clause(clause)
      for a <- acc, b <- next, do: b ++ a
    end)
  end

  defp reversed_condition_matrix_from_clause({:not, {:not, clause}}) do
    reversed_condition_matrix_from_clause(clause)
  end

  defp reversed_condition_matrix_from_clause({:not, {:condition, {:known, fact_template}}}) do
    [[{:not_known, fact_template}]]
  end

  defp reversed_condition_matrix_from_clause({:not, {:condition, {:not_known, fact_template}}}) do
    [[{:known, fact_template}]]
  end

  defp reversed_condition_matrix_from_clause({:not, {:any, clauses}}) do
    reversed_condition_matrix_from_clause(
      {:all, Enum.map(clauses, fn clause -> {:not, clause} end)}
    )
  end

  defp reversed_condition_matrix_from_clause({:not, {:all, clauses}}) do
    reversed_condition_matrix_from_clause(
      {:any, Enum.map(clauses, fn clause -> {:not, clause} end)}
    )
  end
end
