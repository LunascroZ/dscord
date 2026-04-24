defmodule Dscord do
  use Application

  def start(_type, _args) do
    :ets.new(:pseudos, [:named_table, :public, :set])
    children = [
      {Registry, keys: :unique, name: Dscord.Registry},
      {DynamicSupervisor, strategy: :one_for_one, name: Dscord.SalonSupervisor},
      Dscord.ChatServer,
      {Task.Supervisor, name: Dscord.TaskSupervisor}
    ]
    opts = [strategy: :one_for_one, name: Dscord.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
