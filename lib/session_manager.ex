defmodule SessionManager do
  use GenServer
  require Logger

  def start_link(args \\ []) do
   GenServer.start_link(__MODULE__,args, name: client_name(args))
 end


 defp client_name(args) do
 target = Keyword.get(args, :target, :default)
 :"#{target}_server"
 end


 @impl true
 def init(args) do
 target = Keyword.get(args, :target, :default_value_if_not_found)
 default_initial_state = %{canc_counter: 0}
 case target do
 :sess ->
 map_set = %{}
 {:ok, map_set}
 _ ->
 # Default case
 {:ok, default_initial_state}
 end
 end


  # def init(_) do
  #   {:ok, %{}}
  # end

  # def start_link(_) do
  #   GenServer.start_link(__MODULE__, nil, [])
  # end

  @impl true
  def handle_cast({:save_session, username, session_id, time_logged_in}, state) do
    # Add session data to the map
    session_data = %{sess_id: session_id, time_logged_in: time_logged_in}
    updated_state = Map.put(state, username, session_data)
    {:noreply, updated_state}
  end

  def save_session(udm_username, session_id, time_logged_in) do
    GenServer.cast(:sess_server, {:save_session, udm_username, session_id, time_logged_in})
  end

  @impl true
  def handle_call({:get_session, username}, _from, state) do
    # Retrieve session data from the map
    session_data = Map.get(state, username)
    {:reply, session_data, state}
  end

  def get_session(udm_username) do
    GenServer.call(:sess_server, {:get_session, udm_username})
  end

  def handle_cast({:update_session_timestamp, username}, state) do
    case Map.get(state, username) do
      nil ->
        {:noreply, state}
      session_data ->
        updated_session_data = Map.put(session_data, :time_logged_in, :erlang.system_time(:second))
        {:noreply, Map.put(state, username, updated_session_data)}
    end
  end

  def update_session_timestamp(username) do
    GenServer.cast(:sess_server, {:update_session_timestamp, username})
  end

  def handle_cast({:remove_session, username}, state) do
    {:noreply, Map.delete(state, username)}
  end

  def remove_session(username) do
    GenServer.cast(:sess_server, {:remove_session, username})
  end

  def generate_session_id() do
    :crypto.strong_rand_bytes(32) |> Base.encode16()
  end

  def session_exists?(username) do
    case GenServer.call(:sess_server, {:get_session, username}) do
      nil -> false
      _ -> true
    end
  end

end
