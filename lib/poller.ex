defmodule PollProxy.Poller do
  @callback interval() :: interval::Interger.t()
  @callback init(init_args::term) :: {:ok, init_state::term}
  @callback poll(state::term()) :: {:update, update_data::term, next_state::term} | {:no_update, next_state::term}
  @callback handle_update(update_data::term(), subscriber::pid(), state::term()) :: :ok
end
