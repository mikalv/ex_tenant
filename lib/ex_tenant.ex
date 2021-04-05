defmodule ExTenant do
  @moduledoc """
    by calling the `use` macro we should be able to inject all the required behaviour
    to allow us to handle multi-tenancy.

    In your application `Repo` file call the `use` macro as per this example

    use ExTenant,
      config: [
        otp_app: :name_of_your_elixir_phoenix_app,
        adapter: Ecto.Adapters.Postgres,
        tenanted_field: "tenant_id"
      ]

    In order to get the `tenant_id` into the progress dictionary in Phoenix
    we recommend to use a plug - there you should retrieve the `tenant name`
    from something like the `sub domain` in the url. Then using the `tenant name`
    retrieve the `tenant`, and call:

    - Repo.put_tenant_id(tenant_id)

    to insert the `tenant_id` into the process dictionary.

    (The next version of this library will provide a Plug that you can use.
    Watch this space!)

    From here all your Repo callbacks (Repo.get/Repo.one/Repo.all etc) will
    have a where clause applied to them with the `tenant_id` injected into the clause.

    In order to set the `tenant_id` on `insert` and `update` functions do this:

      def changeset(params \\ :empty) do
        params
        |> Repo.inject_tenant_id()
        |> default_changeset()
      end

      defp default_changeset(params) do
        %__MODULE__{}
        |> cast(params, [:field1, :field1, :tenant_id])
      end

    NB: If the `tenant_id` is not set in the changeset, Repo.insert/update callbacks
    will raise a `Postgrex.Error` (not_null_violation)

  """

  @doc false
  defmacro __using__(opts) do
    config = Keyword.get(opts, :config)
    tenanted_field = config[:tenanted_field]
    application = config[:otp_app]
    database_adapter = config[:adapter]
    tenant_key = {__CALLER__.module, String.to_atom(tenanted_field)}

    quote do
      import ExTenant
      require Ecto.Query
      use Ecto.Repo, otp_app: unquote(application), adapter: unquote(database_adapter)

      generate_put_tenant_function(unquote(tenant_key))
      generate_get_tenant_function(unquote(tenant_key))
      generate_default_options_callback()
      generate_inject_tenant_id_callback(unquote(tenanted_field))
      generate_prepare_query_callback()
    end
  end

  @doc false
  defmacro generate_prepare_query_callback() do
    quote do
      def prepare_query(operation, query, opts) do
        cond do
          opts[:skip_tenant_id] || opts[:schema_migration] ->
            {query, opts}

          tenant_id = opts[:tenant_id] ->
            {Ecto.Query.where(query, tenant_id: ^tenant_id), opts}

          true ->
            raise ExTenant.TenantNotSetError
        end
      end
    end
  end

  @doc false
  defmacro generate_inject_tenant_id_callback(tenant_field) do
    quote do
      def inject_tenant_id(params) do
        string_params = for {key, val} <- params, into: %{}, do: {"#{key}", val}

        string_params
        |> Map.put(unquote(tenant_field), get_tenant_id())
      end
    end
  end

  @doc false
  defmacro generate_default_options_callback() do
    quote do
      def default_options(_operation) do
        [tenant_id: get_tenant_id()]
      end
    end
  end

  @doc false
  defmacro generate_put_tenant_function(tenant_key) do
    quote do
      def put_tenant_id(tenant_id) do
        Process.put(unquote(tenant_key), tenant_id)
      end
    end
  end

  @doc false
  defmacro generate_get_tenant_function(tenant_key) do
    quote do
      def get_tenant_id() do
        Process.get(unquote(tenant_key))
      end
    end
  end

  # defp inspect_query_data(operation, query, opts) do
  #  Logger.debug "\n debug operation: #{inspect(operation)}, query: #{inspect(query)}, opts: #{inspect(opts)}"
  # end
end
