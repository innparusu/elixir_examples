defmodule BucketSort.Scheduler do
  @name {:global, __MODULE__}
  def start_link(list) when is_list(list), do: Agent.start_link(fn -> {list, []} end, name: @name)

  def get_list, do: Agent.get(@name, fn {list, _} -> list end)

  def get_clients, do: Agent.get(@name, fn {_, clients} -> clients end)

  def add_clients(client), do: Agent.update(@name, fn {list, clients} -> {list, [client|clients]} end)

  def run do
    clients = get_clients
    send_ready(clients)
    split_list(get_list, clients) |> schedule_processes(length(clients))
  end

  def send_ready(clients) do
    clients |> Enum.each(&(send &1, {:ready, self}))
  end

  defp split_list(list, clients) do
    length(list) / length(clients)
  end

  defp schedule_processes(split, 0) do
    receive do
      {:ready, client} ->
        send client, {:shutdown}
        schedule_processes(split, 0)
    end
  end

  defp schedule_processes(split, n) do
    receive do
      {:ready, client} ->
        send client, {:bucket, split, n}
        schedule_processes(split, n-1)
    end
  end
end

defmodule BucketSort.Client do
  def run do
    task = Task.async(&wait_receive_ready/0)
    Fib.Scheduler.add_clients(task.pid)
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
      { :bucket, split, n} ->
        min = n * split
        max = (n+1) * split
        bsort(BucketSort.Scheduler.get_list, min, max)
        receiver(scheduler)
      { :shutdown } ->
        exit(:normal)
    end
  end

  def bsort(list, min, max) do
    bucket = Enum.filter(list, &(inbucket?(&1, min, max)))
    Enum.sort(bucket)
  end

  def inbucket?(n, min, max) when min <= n and n < max, do: true

  def inbucket?(_, _, _), do: false
end
