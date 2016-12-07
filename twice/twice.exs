defmodule Twice.Scheduler do
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
    list = get_list
    send_ready(clients)
    split_clients(list, clients) |> schedule_processes(length(clients), list)
  end

  defp send_ready(clients) do
    clients |> Enum.each(&(send &1, {:ready, self}))
  end

  defp split_clients(list, clients) do
    Float.ceil(length(list)/length(clients))
  end

  defp schedule_processes(_, 0, _) do
    receive do
      {:ready, client} ->
        send client, {:shutdown}
        delete_client(client)
        if length(get_clients) > 0 do
          schedule_processes(nil, 0, nil)
        end
    end
  end

  defp schedule_processes(split, n, list) do
    receive do
      {:ready, client} ->
        split_list = Enum.slice(list, round((n-1) * split), round(split))
        send client, {:twice, n, split_list}
        schedule_processes(split, n-1, list)
    end
  end

  def get_result(answers) do
    Enum.reduce(Enum.sort(answers, fn {n1, _}, {n2, _} -> n1 <= n2 end), [], fn({_, list}, acc) -> acc ++ list end)
  end
end

defmodule Twice.Client do
  def run do
    task = Task.async(&wait_receive_ready/0)
    Twice.Scheduler.add_client(task.pid)
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
      { :twice, pn, list} ->
        Twice.Scheduler.add_answer({pn, twice(list)})
        receiver(scheduler)
      { :shutdown } ->
        exit(:normal)
    end
  end

  defp twice(list) do
    Enum.map(list, &(&1*&1))
  end
end
