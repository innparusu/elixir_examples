defmodule BucketSort.Scheduler do
  @name {:global, __MODULE__}
  def start_link(list) when is_list(list), do: Agent.start_link(fn -> {list, [], []} end, name: @name)

  def get_list, do: Agent.get(@name, fn {list, _, _} -> list end)

  def get_clients, do: Agent.get(@name, fn {_, clients, _} -> clients end)

  def get_answers, do: Agent.get(@name, fn {_, _, answers} -> answers end)

  def add_client(client), do: Agent.update(@name, fn {list, clients, answers} -> {list, [client|clients], answers} end)

  def add_answer(answer), do: Agent.update(@name, fn {list, clients, answers} -> {list, clients, [answer|answers]} end)

  defp delete_client(client), do: Agent.update(@name, fn {list, clients, answers} -> {list, List.delete(clients, client), answers} end)

  def run do
    clients = get_clients
    send_ready(clients)
    split_bucket(get_list, clients) |> schedule_processes(length(clients))
  end

  defp send_ready(clients) do
    clients |> Enum.each(&(send &1, {:ready, self}))
  end

  defp split_bucket(list, clients) do
    min = Enum.min(list)
    max = Enum.max(list)
    Float.ceil((max - min) / length(clients))
  end

  defp schedule_processes(split, 0) do
    receive do
      {:ready, client} ->
        send client, {:shutdown}
        delete_client(client)
        if length(get_clients) > 0 do
          schedule_processes(split, 0)
        end
    end
  end

  defp schedule_processes(split, n) do
    receive do
      {:ready, client} ->
        send client, {:bucket, split, n}
        schedule_processes(split, n-1)
    end
  end

  def print_result(answers) do
    sorted_list = Enum.reduce(Enum.sort(answers, fn {n1, _}, {n2, _} -> n1 <= n2 end), [], fn({_, list}, acc) -> acc ++ list end)
    IO.puts(inspect(sorted_list))
  end
end

defmodule BucketSort.Client do
  def run do
    task = Task.async(&wait_receive_ready/0)
    BucketSort.Scheduler.add_client(task.pid)
  end

  defp wait_receive_ready do
    receive do
      { :ready, scheduler } ->
        receiver(scheduler)
      { :shutdown } ->
        exit(:normal)
    end
  end

  defp receiver(scheduler) do
    send scheduler, {:ready, self}
    receive do
      { :bucket, split, bn} ->
        list= BucketSort.Scheduler.get_list 
        min = Enum.min(list) + (bn-1) * split
        max = Enum.min(list) + bn * split
        BucketSort.Scheduler.add_answer({bn, bsort(list, min, max, bn)})
        receiver(scheduler)
      { :shutdown } ->
        exit(:normal)
    end
  end

  defp bsort(list, min, max, bn) do
    bucket = Enum.filter(list, &(in_bucket?(&1, min, max, bn)))
    Enum.sort(bucket)
  end

  defp in_bucket?(n, _, max, 1) when n <= max, do: true

  defp in_bucket?(n, min, max, _) when min < n and n <= max, do: true

  defp in_bucket?(_, _, _, _), do: false
end
