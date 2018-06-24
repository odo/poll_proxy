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
