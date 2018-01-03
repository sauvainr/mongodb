defmodule Mongo.App do
  @moduledoc false

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(Mongo.IdServer, []),
      worker(Mongo.PBKDF2Cache, []),
      worker(GenEvent, [[name: Mongo.Events]]),
      supervisor(DBConnection.Task, []),
      supervisor(DBConnection.Ownership.PoolSupervisor, []),
      worker(DBConnection.Watcher, [])
    ]
    Supervisor.start_link(children, strategy: :one_for_one, name: __MODULE__)
  end
end
