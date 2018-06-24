# TODO: exit with last subscriber

defmodule PollProxy.Worker do
  use GenServer
  alias PollProxy.Worker

  defstruct [:subscribers, :poll_module, :poll_module_state, :poll_interval, :name]

  defmodule PollProxy.Worker.Subscriber do
      defstruct [:pid, :monitor]
  end

  alias PollProxy.Worker.Subscriber

  def start_link(args = %{name: name}) do
    GenServer.start_link(__MODULE__, args, name: name)
  end

  def subscribe(server, pid \\ self()) do
    GenServer.call(server, {:subscribe, pid})
  end

  def init(%{poll_module: poll_module, poll_args: poll_args, name: name}) do
    {:ok, poll_module_state} = apply(poll_module, :init, poll_args)
    init_state = %Worker{
      subscribers: %{},
      poll_module: poll_module,
      poll_module_state: poll_module_state,
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
    me = self()
    Process.spawn(
      fn() ->
        poll_result = apply(state.poll_module, :poll, [state.poll_module_state])
        Process.send(me, {:poll_result, poll_result}, [])
      end,
      [:link]
    )
    {:noreply, state}
  end
  def handle_info({:poll_result, {:noupdate, next_poll_module_state}}, state) do
    Process.send_after(self(), :poll, state.poll_interval, [])
    {:noreply, %Worker{state | poll_module_state: next_poll_module_state}}
  end
  def handle_info({:poll_result, {:update, update_data, next_poll_module_state}}, state) do
    Enum.each(
      Map.keys(state.subscribers),
      fn(pid) ->
        apply(state.poll_module, :handle_update, [update_data, pid, next_poll_module_state])
      end
    )
    Process.send_after(self(), :poll, state.poll_interval, [])
    {:noreply, %Worker{state | poll_module_state: next_poll_module_state}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:reply, :ok, next_state} = handle_call({:unsubscribe, pid}, self(), state)
    {:noreply, next_state}
  end
end
