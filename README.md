# PollProxy

## Concept

PollProxy allows many actors to subscribe to the result of a repeating polling operation.
A typical use case is monitoring the change of state of an external resource (DB, API, file...).
The behaviour is defined by implementing `PollProxy.Poller`.

Here is an example where we want to poll the numbers starting from 1 every 100 ms to find increasingly large numbers devisible by a given number. So if we start the poller with a modulus of 3 it should give us `[3, 6, 9, 12 ...]`.

```elixir
defmodule PollProxy.Example.ModPoller do
  @behaviour PollProxy.Poller
  alias PollProxy.Example.ModPoller
  defstruct [:modulus, :i]

  def interval, do: 100

  def init(modulus) do
    {:ok, %ModPoller{modulus: modulus, i: 0}}
  end

  def poll(%ModPoller{modulus: modulus, i: last_i} = state) do
    i = last_i + 1
    next_state = %ModPoller{state | i: i}
    case rem(i, modulus) do
      0 -> {:update, i, next_state}
      _ -> {:noupdate, next_state}
    end
  end

  def handle_update(update_data, subscriber, _state) do
    Process.send(subscriber, {:update, update_data}, [])
    :ok
  end

end
```

So `init/n` is called once when the proxy is started and computes the intial state. While polling, `poll/1` is called repeatedly, first with the inial state and later with the states returned by earlies invocations.

If polling discovers an update `poll/1` returns `{:update, update_data, state}` and the proxy will call `handle_update/3` for all subscribers. This call will happen in a spawned process so it will not block the proxy.

## starting and subscribing/unsubscribing
PollProxy is its own application so the proxies are supervised.

### starting manually

```elixir
iex(1)> PollProxy.start_proxy(PollProxy.Example.ModPoller, [7], :mod7_poller)
{:ok, #PID<0.115.0>}
iex(2)> PollProxy.subscribe(:mod7_poller)
:ok
[... a few moments pass ...]
iex(3)> flush
{:update, 7}
{:update, 14}
{:update, 21}
{:update, 28}
{:update, 35}
{:update, 42}
:ok
iex(3)> PollProxy.unsubscribe(:mod7_poller)
:ok
iex(4)> Process.whereis(:mod7_poller)
#PID<0.115.0>
```
### starting lazily/dynamically

If the intial arguments are not known beforehand you can also start a proxy and subscribe in one operation.
The name for the proxy is then computed from the poll_module and the poll_args and does not have to be passed around. When a different process wants to subscribe to a proxy with this poll_module/poll_args signature it subscribe to the running proxy.

Addtionaly the proxie workers are started with `stop_when_empty` enabled, meaning they are not only lazily started but also shut themselves down after the last process unsubscribes.

```elixir
iex(1)> {:ok, server}  = PollProxy.start_proxy_and_subscribe(PollProxy.Example.ModPoller, [7], self())
{:ok, :poll_proxy_1736236754}
[... a few moments pass ...]
iex(2)> flush
{:update, 7}
{:update, 14}
{:update, 21}
{:update, 28}
{:update, 35}
{:update, 42}
:ok
iex(3)> PollProxy.unsubscribe(server)
:ok
iex(4)> Process.whereis(server)
nil
```
