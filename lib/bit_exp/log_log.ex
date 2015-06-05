defmodule BitExp.LogLog do
  use Bitwise

  @register_bits 6
  @registers :math.pow(2, @register_bits)
  @hash :sha256
  @alpha 0.39701

  def loglog(set) do
     @alpha * @registers * :math.pow(2, 1/@registers * sum(set))
  end

  def sum(set) do
    set

    # stringify
    |> Stream.map(&to_string &1)

    # hash
    |> Stream.map(&:crypto.hash(@hash, &1))

    # the 24 least significant bits (24 1-bits, native endianness)
    |> Stream.map(fn <<a :: size(24)-unit(1)-native, _rest :: binary>> -> a end)

    # {bucket_index, bits}
    |> Stream.map(fn bits -> {bucket_index(bits, @register_bits), bits} end)

    # dropbucket index bits
    |> Stream.map(fn {bucket_index, bits} ->
      bits_without_last_five =
        bits
        |> digits(2) # base 2
        |> Enum.drop(-(@register_bits)) # drop last N

      {bucket_index, least_significant_one(bits_without_last_five)}
    end)

    # update buckets with largest values
    |> Enum.reduce(HashDict.new, fn {bucket_index, zeros}, buckets ->
      case HashDict.get(buckets, bucket_index) do
        nil                      -> HashDict.put(buckets, bucket_index, zeros)
        value when zeros > value -> HashDict.put(buckets, bucket_index, zeros)
        _value                   -> buckets
      end
    end)

    # sum
    |> Enum.reduce(0, fn {_, val}, acc -> acc + val end)
  end

  @spec least_significant_one(binary) :: integer
  def least_significant_one(bitlist) do
    bitlist
    |> Enum.reverse
    |> do_least_significant_one(0)
  end

  def do_least_significant_one([], counter), do: counter + 1

  def do_least_significant_one([bit|rest], counter) when bit == 0 do
    do_least_significant_one(rest, counter + 1)
  end
  def do_least_significant_one([bit|_rest], counter) when bit == 1 do
    do_least_significant_one([], counter)
  end


  @spec bucket_index(integer, integer) :: integer
  def bucket_index(bits, k) do
    bits &&& ((1 <<< k) - 1)
  end

  ####################
  # FROM ELIXIR HEAD #
  ####################
  @spec digits(non_neg_integer, pos_integer) :: [non_neg_integer]
  def digits(n, base \\ 10) when is_integer(n)    and n >= 0
                            and  is_integer(base) and base >= 2 do
    do_digits(n, base, [])
  end

  defp do_digits(0, _base, []),  do: [0]
  defp do_digits(0, _base, acc), do: acc
  defp do_digits(n, base, acc)  do
    do_digits div(n, base), base, [rem(n, base) | acc]
  end

  ####################
  # FROM ELIXIR HEAD #
  ####################
  @spec undigits([integer], integer) :: integer
  def undigits(digits, base \\ 10) when is_integer(base) do
    do_undigits(digits, base, 0)
  end

  defp do_undigits([], _base, acc), do: acc
  defp do_undigits([digit | tail], base, acc) do
    do_undigits(tail, base, acc * base + digit)
  end
end
