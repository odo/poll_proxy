defmodule PollProxy.Poller do
  @callback interval() :: Interger.t()
  @callback poll(term()) :: {:update, term} | :no_update
  @callback handle_update(pid(), term()) :: :ok
end
