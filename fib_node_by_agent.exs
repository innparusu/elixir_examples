defmodule Fib.Scheduler do
  @name {:global, __MODULE__}
  def start_link, do: Agent.start_link(fn -> {[], [], []} end, name: @name)

  def get_fibs, do: Agent.get(@name, &(&1))

  def get_fib_clients, do: Agent.get(@name, fn {clients, _, _} -> clients end)

  def get_fib_num_calculate, do: Agent.get(@name, fn {_, num_calculate, _} -> num_calculate end)

  def get_fib_answers, do: Agent.get(@name, fn {_, _, answers} -> answers end)

  def add_fib_clients(client), do: Agent.update(@name, fn {clients, num_calculate, answers} -> {[client|clients], num_calculate, answers} end)

  def add_fib_num_calculate(n), do: Agent.update(@name, fn {clients, num_calculate, answers} -> {clients, [n|num_calculate], answers} end)

  def add_fib_answers(n), do: Agent.update(@name, fn {clients, num_calculate, answers} -> {clients, num_calculate, [n|answers]} end)

  defp remove_fib_num_calculate, do: Agent.update(@name, fn {clients, [n|tail], answers} -> {clients, tail, answers} end)

  def run do
    get_fib_clients |> send_ready
  end

  defp send_ready(clients) do
    clients |> Enum.each(&(send &1, {:ready, self}))
    schedule_processes
  end

  defp schedule_processes do
    num_calculate = get_fib_num_calculate
    receive do
      {:ready, client} when length(num_calculate) > 0 ->
        send client, {:fib, List.first(num_calculate)}
        remove_fib_num_calculate
        schedule_processes
      {:ready, client} ->
        send client, {:shutdown}
    end
  end
end

defmodule Fib.Client do
  def run do
    task = Task.async(&wait_receive_ready/0)
    Fib.Scheduler.add_fib_clients(task.pid)
  end

  def wait_receive_ready do
    receive do
      { :ready, scheduler } ->
        IO.puts("ready")
        receiver(scheduler)
      { :shutdown } ->
        exit(:normal)
    end
  end

  def receiver(scheduler) do
    send scheduler, {:ready, self}
    receive do
      { :fib, n } ->
        Fib.Scheduler.add_fib_answers(fib_calc(n))
        receiver(scheduler)
      { :shutdown } ->
        exit(:normal)
    end
  end

  defp fib_calc(n), do: _fib_calc(n, 0, 1)
  defp _fib_calc(0, prev_acc, _), do: prev_acc
  defp _fib_calc(n, prev_acc, acc), do: _fib_calc(n-1, acc, prev_acc + acc)
end
