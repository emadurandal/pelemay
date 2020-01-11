defmodule Pelemay.Generator.Native_CL do
  alias Pelemay.Db
  alias Pelemay.Generator
  
  # generate OpenCl Code
  def generate do
    Db.get_arguments()
    |> Enum.map(&(&1 |> generate_cl_code))
  end

  defp generate_cl_code([name, func_num_list]) do
    Generator.libcl_func(name)
    |> write(name, func_num_list)
  end

  defp write(file, name, func_num_list) do
    str = 
      generate_function(func_num_list)
      |> basic(name)
    file |> File.write(str)
  end 

  defp basic(str,name) do
    """
    //This file was generated by Pelemay.generator.Native_CL
    __kernel void #{name}(__global long *vec,__global int *size) {
      size_t gid = get_global_id(0);
      size_t gsize = get_global_size(0);
      int rep, i;
      rep = ((*size)-gid)/gsize + 1;
      for(i=0;i<rep;i++){
        long value = vec[gid+gsize*i];
    #{str}   
        vec[gid+gsize*i] = value;
      }
    }
    """
  end

  defp generate_function(list) do
    list
    |> Enum.map(&(&1 |> generate_expr))
    |> Enum.reduce(fn x, acc -> x<>acc end)
  end 

  defp generate_expr(func_num) do
    Db.get_function(func_num)
    |> enum_map
  end

  defp enclosure(str) do
    "(#{str})"
  end

  defp make_expr(operators, args, type)
       when is_list(operators) and is_list(args) do
    args = args |> to_string(:args)

    operators = operators |> to_string(:op)

    last_arg = List.last(args)

    expr =
      Enum.zip(args, operators)
      |> Enum.reduce("", &make_expr/2)

    if type == "double" && String.contains?(expr, "%") do
      "(vec_double[i])"
    else
      enclosure(expr <> last_arg)
    end
  end

  defp make_expr({arg, operator}, acc) do
    enclosure(acc <> arg) <> operator
  end

  #defp to_string(args, :args, "double") do
   # args
    #|> Enum.map(&(&1 |> arg_to_string))
  #end

  defp to_string(args, :args) do
    args
    |> Enum.map(&(&1 |> arg_to_string))
  end

  defp to_string(operators, :op) do
    operators
    |> Enum.map(&(&1 |> operator_to_string))
  end

  defp arg_to_string(arg) do
    case arg do
      {:&, _meta, [1]} -> "value"
      {_, _, nil} -> "value"
      other -> "#{other}"
    end
  end

  defp operator_to_string(operator) do
    case operator do
      :rem -> "%"
      other -> other |> to_string
    end
  end

  # defp enum_map_(str, operator, num)
  defp enum_map([%{args: args, operators: operators}]) do
    expr_l = make_expr(operators, args, "long")

    # expr_d = case operators do
    #   :% -> ""
    #   _ -> "#{str_operator}  #{args}"
    # end

    # expr_l = "#{str_operator} (long)#{args}"

    """
        value = #{expr_l};
    """
  end

end