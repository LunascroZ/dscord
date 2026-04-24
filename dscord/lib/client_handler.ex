defmodule Dscord.ClientHandler do
  require Logger

  def start(socket) do
    :gen_tcp.send(socket, "Bienvenue sur Dscord!\r\n")
    :gen_tcp.send(socket, "Entre ton pseudo : ")
    {:ok, pseudo} = :gen_tcp.recv(socket, 0)
    pseudo = String.trim(pseudo)

    :gen_tcp.send(socket, "Salons disponibles : #{salons_dispo()}\r\n")
    :gen_tcp.send(socket, "Rejoins un salon (ex: general) : ")
    {:ok, salon} = :gen_tcp.recv(socket, 0)
    salon = String.trim(salon)

    rejoindre_salon(socket, pseudo, salon)
  end

  defp rejoindre_salon(socket, pseudo, salon) do
    case Registry.lookup(Dscord.Registry, salon) do
      [] ->
        DynamicSupervisor.start_child(
          Dscord.SalonSupervisor,
          {Dscord.Salon, salon})
      _ -> :ok
    end

    Dscord.Salon.rejoindre(salon, self())
    Dscord.Salon.broadcast(salon, "📢 #{pseudo} a rejoint ##{salon}\r\n")
    :gen_tcp.send(socket, "Tu es dans ##{salon} — écris tes messages !\r\n")

    loop(socket, pseudo, salon)
  end

  defp loop(socket, pseudo, salon) do
    receive do
      {:message, msg} ->
        :gen_tcp.send(socket, msg)
    after 0 -> :ok
    end

    case :gen_tcp.recv(socket, 0, 100) do
      {:ok, msg} ->
        msg = String.trim(msg)
        Dscord.Salon.broadcast(salon, "[#{pseudo}] #{msg}\r\n")
        loop(socket, pseudo, salon)

      {:error, :timeout} ->
        loop(socket, pseudo, salon)

      {:error, reason} ->
        Logger.info("Client déconnecté : #{inspect(reason)}")
        Dscord.Salon.broadcast(salon, "👋 #{pseudo} a quitté ##{salon}\r\n")
        Dscord.Salon.quitter(salon, self())
    end
  end

  defp salons_dispo do
    case Dscord.Salon.lister() do
      [] -> "aucun (tu seras le premier !)"
      salons -> Enum.join(salons, ", ")
    end
  end
end
