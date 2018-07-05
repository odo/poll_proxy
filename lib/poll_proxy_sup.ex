defmodule PollProxy.Supervisor do
  # Automatically defines child_spec/1
  use DynamicSupervisor

  def start_link(arg) do
    DynamicSupervisor.start_link(__MODULE__, arg, name: __MODULE__)
  end

  def init(_arg) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def start_child(poll_module, poll_args, name, options)
    when is_atom(poll_module) and is_list(poll_args) and is_atom(name) and is_list(options) do
    stop_when_empty = Keyword.get(options, :stop_when_empty, false)
    start_args = %{poll_module: poll_module, poll_args: poll_args, name: name, stop_when_empty: stop_when_empty}
    DynamicSupervisor.start_child(
      __MODULE__,
      %{
        id: name,
        start: {PollProxy.Worker, :start_link, [start_args]},
        restart: :transient
      }
    )
  end

end
