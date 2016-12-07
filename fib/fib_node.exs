defmodule Fib do

  @interval 2000
  @name :fib

  def start(num_clients, num_calculate) do
    pid = spawn(__MODULE__, :generator, [[], num_clients, num_calculate])
    :global.register_name(@name, pid)
  end

  def register(client_pid) do
    send :global.whereis_name(@name), { :register, client_pid }
  end

  def generator(clients, num_clients, num_calculate) when length(clients) == num_clients do
    start_schduler(clients, num_calculate)
  end

  def generator(clients, num_clients, num_calculate) do
    receive do
      { :register, pid } ->
        IO.puts "registering #{inspect pid}"
        generator([pid|clients], num_clients, num_calculate)
    end
  end

  def start_schduler(clients, num_calculate) do
    to_calculate = Enum.to_list(1..num_calculate)
    {time, result} = :timer.tc(
     Scheduler, :run,
     [clients, to_calculate]
    )
    IO.puts inspect result
    IO.puts "\n # time(s)"
    :io.format "~.2f~n", [time/1000000.0]
  end
end

defmodule Scheduler do

  def run(clients, to_calculate) do
    send_ready(clients)
    clients |> schedule_processes(to_calculate, [])
  end

  def send_ready(clients) do
    Enum.each(clients, fn client -> send client, {:ready, self} end)
  end

  defp schedule_processes(processes, queue, results) do
    receive do
      {:ready, pid} when length(queue) > 0 ->
        [next | tail] = queue
        send pid, {:fib, next}
        schedule_processes(processes, tail, results)

      {:ready, pid} ->
        send pid, {:shutdown}
        if length(processes) > 1 do
          schedule_processes(List.delete(processes, pid), queue, results)
        else
          Enum.sort(results, fn {n1, _}, {n2, _} -> n1 <= n2 end)
        end

      {:answer, number, result} ->
        schedule_processes(processes, queue, [ {number, result} | results ])
    end
  end
end

defmodule Client do
  def start do
    pid = spawn(__MODULE__, :wait_receive_ready, [])
    Fib.register(pid)
  end
  
  def wait_receive_ready do
    receive do
      { :ready, scheduler } ->
        IO.puts("ready")
        receiver(scheduler)
    end
  end

  def receiver(scheduler) do
    send scheduler, {:ready, self}
    receive do
      { :fib, n } ->
        send scheduler, {:answer, n, fib_calc(n)}
        receiver(scheduler)
      { :shutdown } ->
        exit(:normal)
    end
  end

  defp fib_calc(n), do: _fib_calc(n, 0, 1)
  defp _fib_calc(0, prev_acc, _), do: prev_acc
  defp _fib_calc(n, prev_acc, acc), do: _fib_calc(n-1, acc, prev_acc + acc)
end
