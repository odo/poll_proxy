defmodule PollProxy do

  use Application

  alias PollProxy.Worker

  def start(_type, _args) do
    children = [PollProxy.Supervisor]
    Supervisor.start_link(children, strategy: :one_for_one)
  end

  def start_proxy(poll_module, poll_args, name, options \\ []) do
    PollProxy.Supervisor.start_child(poll_module, poll_args, name, options)
  end

  def start_proxy_and_subscribe(poll_module, poll_args, pid, options \\ []) do
    options = Keyword.put(options, :stop_when_empty, Keyword.get(options, :stop_when_empty, true))
    name = name_from_term({poll_module, poll_args})
    case start_proxy(poll_module, poll_args, name, options) do
      {:error, {:already_started, _pid}} -> :ok
      {:ok, _pid} -> :ok
    end
    :ok = subscribe(name, pid, options)
    {:ok, name}
  end

  def subscribe(name, pid \\ self(), options \\ []) do
    Worker.subscribe(name, pid, options)
  end

  def unsubscribe(name, pid \\ self()) do
    Worker.unsubscribe(name, pid)
  end

  defp name_from_term(term) do
      term
      |> :erlang.term_to_binary
      |> :erlang.crc32
      |> Integer.to_string
      |> String.replace_prefix("", "poll_proxy_")
      |> String.to_atom
  end

end
