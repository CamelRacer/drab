defmodule Drab.Controller do
  @moduledoc """
  Turns on the Drab Commander on the pages generated by this controller.

  To enable Drab on the specific page, you need to add the directive `use Drab.Controller` to the corresponding
  controller first, the `use Drab.Commander` in the commander module.

      defmodule DrabExample.PageController do
        use Example.Web, :controller
        use Drab.Controller

        def index(conn, _params) do
          render conn, "index.html"
        end
      end

  By default Drab searches for the Commander with the name corresponding to the Controller, eg. NameController -
  NameCommander. You may specify the commander module by using `commander` option:

      use Drab.Controller, commander: MyApp.NameController

  See also `Drab.Commander`
  """

  defmacro __using__(options) do
    quote bind_quoted: [options: options] do
      Module.put_attribute(__MODULE__, :__drab_opts__, options)

      unless Module.defines?(__MODULE__, {:__drab__, 0}) do
        def __drab__() do
          # default commander is named as a controller
          # controller_path = __MODULE__ |> Atom.to_string() |> String.split(".")
          # commander = controller_path |> List.last() |> String.replace("Controller", "Commander")
          # commander = controller_path |> List.replace_at(-1, commander) |> Module.concat()
          # view = controller_path |> List.last() |> String.replace("Controller", "View")
          # view = controller_path |> List.replace_at(-1, view) |> Module.concat()
          commander = Drab.Config.commander_for(__MODULE__)
          view = Drab.Config.view_for(commander)

          Enum.into(@__drab_opts__, %{commander: commander, view: view, controller: __MODULE__})
        end
      end
    end
  end
end
