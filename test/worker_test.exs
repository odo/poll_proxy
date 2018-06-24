defmodule PollProxyWorkerTest do
  use ExUnit.Case
  alias PollProxy.Worker

  defmodule TestPoller do
    @behaviour PollProxy.Poller

    def interval, do: 10

    def init(mode) do
      {:ok, mode}
    end

    def poll(:always_update = mode) do
      {:update, :next_value, mode}
    end
    def poll(:never_update = mode) do
      {:no_update, mode}
    end
    def handle_update(update_data, subscriber, _mode) do
      Process.send(subscriber, {:update, update_data}, [])
      :ok
    end
  end

  test "start and register" do
    name = :test_name
    {:ok, pid} = Worker.start_link(%{poll_module: TestPoller, poll_args: [:never_update], name: name})
    assert pid == Process.whereis(name)
  end

  test "subscribe and unsubscribe" do
    me = self()
    name = :test_name
    {:ok, init_state} = Worker.init(%{poll_module: TestPoller, poll_args: [:never_update], name: name})
    assert  {:reply, [], init_state} == Worker.handle_call(:subscribers, me, init_state)

    {:reply, :ok, subscribed_state} = Worker.handle_call({:subscribe, me}, me, init_state)
    assert  {:reply, [{^me, _}], ^subscribed_state} = Worker.handle_call(:subscribers, me, subscribed_state)

    {:reply, :ok, unsubscribed_state} = Worker.handle_call({:unsubscribe, me}, me, init_state)
    assert  {:reply, [], ^unsubscribed_state} = Worker.handle_call(:subscribers, me, unsubscribed_state)

    {:reply, :ok, unsubscribed_state} = Worker.handle_call({:unsubscribe, me}, me, unsubscribed_state)
    assert  {:reply, [], ^unsubscribed_state} = Worker.handle_call(:subscribers, me, unsubscribed_state)
  end

  test "subscribe and unsubscribes when subscriber dies" do
    me = self()
    name = :test_name
    {:ok, init_state} = Worker.init(%{poll_module: TestPoller, poll_args: [:never_update], name: name})
    {:reply, :ok, subscribed_state} = Worker.handle_call({:subscribe, me}, me, init_state)
    {:noreply, unsubscribed_state} = Worker.handle_info({:DOWN, :the_ref, :process, me, :the_reason}, subscribed_state)
    assert  {:reply, [], ^unsubscribed_state} = Worker.handle_call(:subscribers, me, unsubscribed_state)
  end

  test "notify" do
    me = self()
    name = :test_name
    {:ok, init_state} = Worker.init(%{poll_module: TestPoller, poll_args: [:always_update], name: name})
    {:reply, :ok, subscribed_state} = Worker.handle_call({:subscribe, me}, me, init_state)
    Worker.handle_info(:poll, subscribed_state)
    assert_receive({:update, :next_value}, 100)
  end

end
