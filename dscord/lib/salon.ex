defmodule Dscord.Salon do
  use GenServer

  def start_link(name) do
    GenServer.start_link(__MODULE__, %{name: name, clients: [], historique: [], password: nil},
      name: via(name))
  end

  def rejoindre(salon, pid), do: GenServer.call(via(salon), {:rejoindre, pid})
  def quitter(salon, pid),   do: GenServer.call(via(salon), {:quitter, pid})
  def broadcast(salon, msg), do: GenServer.cast(via(salon), {:broadcast, msg})
  def lister do
    Registry.select(Dscord.Registry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  def init(state), do: {:ok, state}

  def handle_call({:rejoindre, pid}, _from, state) do
    Process.monitor(pid)
    state.historique
    |> Enum.reverse()
    |> Enum.each(fn msg -> send(pid, {:message, "[Archives] #{msg}"}) end)
    new_state = %{state | clients: [pid | state.clients]}
    {:reply, :ok, new_state}
  end

  def handle_call({:quitter, pid}, _from, state) do
  new_state =%{state | clients: List.delete(state.clients, pid)}
  {:reply, :ok,new_state}
  end

  def handle_call({:set_password, pass}, _from, state) do
  {:reply, :ok, %{state | password: pass}}
end

  def handle_call({:check_password, pass_tente}, _from, state) do
  reponse = cond do
    state.password == nil -> :ok
    state.password == pass_tente -> :ok
    true -> :error
  end
  {:reply, reponse, state}
  end

  
  def handle_cast({:broadcast, msg}, state) do
  Enum.each(state.clients, fn client_pid -> send(client_pid, {:message, msg}) end)
  new_historique = [msg | state.historique] |> Enum.take(10)
  {:noreply, %{state |historique: new_historique}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
  new_state = %{state | clients: List.delete(state.clients, pid)}
  {:noreply, new_state}
  end

  defp via(name), do: {:via, Registry, {Dscord.Registry, name}}

  def proteger(salon, password), do: GenServer.call(via(salon), {:set_password, password})
  def verifier_password(salon, password), do: GenServer.call(via(salon), {:check_password, password})




end
