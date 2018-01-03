defmodule Mongo.UrlParser do
  @moduledoc "Mongo connection URL parsing util"

  @mongo_url_regex ~r/^mongodb:\/\/((?<username>[^:]+):(?<password>[^@]+)@)?(?<seeds>[^\/]+)(\/(?<database>[^?]+))?(\?(?<options>.*))?$/

  # https://docs.mongodb.com/manual/reference/connection-string/#connections-connection-options
  @mongo_options %{
    # Path options
    "username" => :string,
    "password" => :string,
    "database" => :string,
    # Query options
    "replicaSet" => :string,
    "ssl" => ["true", "false"],
    "connectTimeoutMS" => :number,
    "socketTimeoutMS" => :number,
    "maxPoolSize" => :number,
    "minPoolSize" => :number,
    "maxIdleTimeMS" => :number,
    "waitQueueMultiple" => :number,
    "waitQueueTimeoutMS" => :number,
    "w" => :string,
    "wtimeoutMS" => :number,
    "journal" => ["true", "false"],
    "readConcernLevel" => ["local", "majority", "linearizable", "available"],
    "readPreference" => ["primary", "primaryPreferred", "secondary", "secondaryPreferred", "nearest"],
    "maxStalenessSeconds" => :number,
    "readPreferenceTags" => :string,
    "authSource" => :string,
    "authMechanism" => ["SCRAM-SHA-1", "MONGODB-CR", "MONGODB-X509", "GSSAPI", "PLAIN"],
    "gssapiServiceName" => :string,
    "localThresholdMS" => :number,
    "serverSelectionTimeoutMS" => :number,
    "serverSelectionTryOnce" => ["true", "false"],
    "heartbeatFrequencyMS" => :number,
    "retryWrites" => ["true", "false"],
    "uuidRepresentation" => ["standard", "csharpLegacy", "javaLegacy", "pythonLegacy"],
    # Elixir Driver options
    "type" => ["unknown", "single", "replicaSetNoPrimary", "sharded"]
  }

  @driver_option_map %{
    max_pool_size: :pool_size,
    replica_set: :set_name,
    w_timeout: :wtimeout
  }

  defp parse_option_value(_key, ""), do: nil
  defp parse_option_value(key, value) do
    case @mongo_options[key] do
      :number -> String.to_integer(value)
      :string -> value
      enum when is_list(enum) ->
        if Enum.member?(enum, value) do
          value
          |> Macro.underscore()
          |> String.to_atom()
        end
      _other -> nil
    end
  end

  defp add_option([key, value], opts), do:
    add_option({key, value}, opts)
  defp add_option({key, value}, opts) do
    case parse_option_value(key, value) do
      nil -> opts
      value ->
        key = key
        |> Macro.underscore()
        |> String.to_atom()
        Keyword.put(opts, @driver_option_map[key] || key, value)
    end
  end
  defp add_option(_other, acc), do: acc

  defp parse_query_options(opts, %{"options" => options}) when is_binary(options) do
    options
    |> String.split("&")
    |> Enum.map(fn(option) -> String.split(option, "=") end)
    |> Enum.reduce(opts, &add_option/2)
  end
  defp parse_query_options(opts, _frags), do: opts

  defp parse_seeds(opts, %{"seeds" => seeds}) when is_binary(seeds) do
    Keyword.put(opts, :seeds, String.split(seeds, ","))
  end
  defp parse_seeds(opts, _frags), do: opts

  @spec parse_url(Keyword.t) :: Keyword.t
  def parse_url(opts) when is_list(opts) do
    with  {url, opts} when is_binary(url) <- Keyword.pop(opts, :url),
          frags when frags != nil         <- Regex.named_captures(@mongo_url_regex, url),
          opts                            <- parse_seeds(opts, frags),
          opts                            <- parse_query_options(opts, frags),
          # Parse fixed parameters (database, username & password) & merge them with query options
          opts                            <- Enum.reduce(frags, opts, &add_option/2)
    do
      opts
    else
      _other -> opts
    end
  end
  def parse_url(opts), do: opts
end
