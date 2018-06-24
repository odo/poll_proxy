defmodule PollProxy.Worker do
  use GenServer
  alias PollProxy.Worker

  defstruct [:subscribers, :poll_module, :poll_args, :poll_interval, :name]

  defmodule PollProxy.Worker.Subscriber do
      defstruct [:pid, :monitor]
  end

  alias PollProxy.Worker.Subscriber

  def start_link(args = %{name: name}) do
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def init(%{poll_module: poll_module, poll_args: poll_args, name: name}) do
    init_state = %Worker{
      subscribers: %{},
      poll_module: poll_module,
      poll_args: poll_args,
      poll_interval: poll_module.interval,
      name: name
    }
    Process.send(self(), :poll, [])
    {:ok, init_state}
  end

  def handle_call({:subscribe, pid}, _from, %Worker{subscribers: subscribers} = state) do
    subscriber = %Subscriber{pid: pid, monitor: Process.monitor(pid)}
    next_subscribers = Map.put(subscribers, pid, subscriber)
    {:reply, :ok, %Worker{state | subscribers: next_subscribers}}
  end
  def handle_call({:unsubscribe, pid}, _from, %Worker{subscribers: subscribers} = state) do
    next_subscribers =
    case Map.get(subscribers, pid) do
      :nil ->
        subscribers
      %Subscriber{} = subscriber ->
        Process.demonitor(subscriber.monitor)
        Map.delete(subscribers, pid)
    end
    {:reply, :ok, %Worker{state | subscribers: next_subscribers}}
  end
  def handle_call(:subscribers, _from, %Worker{subscribers: subscribers} = state) do
    {:reply, Enum.into(subscribers, []), state}
  end

  def handle_info(:poll, state) do
    case apply(state.poll_module, :poll, state.poll_args) do
      :no_update ->
          :noop
      {:update, update_data} ->
        Map.keys(state.subscribers)
        |> Enum.each(
          fn(pid) ->
            apply(state.poll_module, :handle_update, [pid, update_data])
          end
        )
    end
    Process.send_after(self(), :poll, state.poll_interval, [])
    {:noreply, state}
  end
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:reply, :ok, next_state} = handle_call({:unsubscribe, pid}, self(), state)
    {:noreply, next_state}
  end
end
