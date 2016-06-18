Enum.map((1..100), fn x -> 
 cond do
   rem(x, 15) == 0 ->
     "FizzBuzz"
   rem(x, 3) == 0 ->
     "Fizz"
   rem(x, 5) == 0 ->
     "Buzz"
   true ->
     to_string x
 end
end)
