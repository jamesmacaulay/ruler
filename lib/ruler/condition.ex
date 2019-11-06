defmodule Ruler.Condition do
  @type variable_name :: atom() | String.t()
  @type variable :: {:var, variable_name}
  @type constant :: {:const, term}

  @type test :: variable | constant

  @type t :: {test, test, test}

  @spec nil_if_not_const(test) :: {:const, term} | nil
  def nil_if_not_const(test) do
    if match?({:const, _}, test) do
      test
    else
      nil
    end
  end

  @spec constants({test, test, test}) ::
          {nil | constant, nil | constant, nil | constant}
  def constants({id, attr, val}) do
    {nil_if_not_const(id), nil_if_not_const(attr), nil_if_not_const(val)}
  end
end
