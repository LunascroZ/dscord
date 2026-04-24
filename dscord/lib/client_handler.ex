defmodule Dscord.ClientHandler do
  require Logger

  def start(socket) do
    :gen_tcp.send(socket, "Bienvenue sur Dscord!\r\n")
    pseudo = choisir_pseudo(socket)
    :gen_tcp.send(socket, "Salons disponibles : #{salons_dispo()}\r\n")
    premier_salon(socket,pseudo)
  end

  defp premier_salon(socket, pseudo) do
    :gen_tcp.send(socket, "Quel salon veux-tu rejoindre ? (ex: general) : ")
    {:ok, choix} = :gen_tcp.recv(socket, 0)
    choix = String.trim(choix)
    {nom, pass} = case String.split(choix, " ", parts: 2) do
    [n, p] -> {n, p}
    [n] -> {n, nil}
  end
  assurer_salon_existe(nom)
  case Dscord.Salon.verifier_password(nom, pass) do
      :ok ->
        rejoindre_salon(socket, pseudo, nom)
      :error ->
        :gen_tcp.send(socket, "Accès refusé : mot de passe incorrect.\r\n")
        premier_salon(socket, pseudo)
    end
  end


  defp assurer_salon_existe(salon) do
  case Registry.lookup(Dscord.Registry, salon) do
    [] ->
      DynamicSupervisor.start_child(
        Dscord.SalonSupervisor,
        {Dscord.Salon, salon})
    _ -> :ok
  end
end

  defp rejoindre_salon(socket, pseudo, salon) do
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


        nouveau_salon = if String.starts_with?(msg, "/") do
          gerer_commande(socket, pseudo, salon, msg)
        else
           Dscord.Salon.broadcast(salon, "#{pseudo}: #{msg}\r\n")
           salon
        end


        loop(socket, pseudo, nouveau_salon)

      {:error, :timeout} ->

        loop(socket, pseudo, salon)

      {:error, reason} ->

        Logger.info("Client déconnecté (#{pseudo}) : #{inspect(reason)}")


        Dscord.Salon.broadcast(salon, "👋 #{pseudo} a quitté ##{salon}\r\n")
        Dscord.Salon.quitter(salon, self())
        liberer_pseudo(pseudo)


    end
  end

  defp salons_dispo do
    case Dscord.Salon.lister() do
      [] -> "aucun (tu seras le premier !)"
      salons -> Enum.join(salons, ", ")
    end
  end

  defp pseudo_disponible?(pseudo) do
    case :ets.lookup(:pseudos,pseudo) do
      [] ->
        true
      [_autres] ->
        false
end
end

defp reserver_pseudo(pseudo) do
:ets.insert(:pseudos, {pseudo, self()})
end


defp liberer_pseudo(pseudo) do
:ets.delete(:pseudos, pseudo)
end

defp choisir_pseudo(socket) do
  :gen_tcp.send(socket, "Entre ton pseudo : ")
  {:ok, pseudo} = :gen_tcp.recv(socket, 0)
  pseudo = String.trim(pseudo)
if pseudo_disponible?(pseudo) do
      reserver_pseudo(pseudo)
      pseudo
      else
        :gen_tcp.send(socket, "Désolé, ce pseudo est déjà pris...\r\n")
        choisir_pseudo(socket)
    end
end


defp gerer_commande(socket,pseudo,salon,commande) do
  case String.split(commande, " ", parts: 2) do
    ["/list"] ->
      salons = Dscord.Salon.lister()
      :gen_tcp.send(socket, "Salons disponibles : #{Enum.join(salons, ", ")}\r\n")
      salon

    ["/join",reste] ->
      {nom_salon, password} = case String.split(reste, " ", parts: 2) do
      [nom, pass] -> {nom, pass}
      [nom] -> {nom, nil}
   end
      case Dscord.Salon.verifier_password(nom_salon, password) do
        :ok ->
          Dscord.Salon.quitter(salon, self())
          rejoindre_salon(socket, pseudo, nom_salon)
        :error ->
          :gen_tcp.send(socket, " Mot de passe incorrect pour ##{nom_salon}\r\n")
          salon
      end

    ["/quit"] ->
      liberer_pseudo(pseudo)
      :gen_tcp.close(socket)
      exit(:normal)
    ["/protect",password] ->
      Dscord.Salon.proteger(salon, password)
      :gen_tcp.send(socket, " Le salon ##{salon} est maintenant protégé par mot de passe.\r\n")
      salon
    _ ->
      :gen_tcp.send(socket, "Commande inconnue\r\n")
      salon

end
end
end
