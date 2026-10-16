defmodule ElixiratorChallengeWeb.FuelLive do
  use ElixiratorChallengeWeb, :live_view

  alias ElixiratorChallenge.FuelCalculator

  @actions [Launch: "launch", Land: "land"]
  @planets [Earth: "earth", Moon: "moon", Mars: "mars"]

  @impl true
  def mount(_params, _session, socket) do
    {:ok,
     socket
     |> assign(:actions, @actions)
     |> assign(:planets, @planets)
     |> assign(:mass, "")
     |> assign(:steps, [%{action: "launch", planet: "earth"}])
     |> recalculate()}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.header>
        Interplanetary Fuel Calculator
        <:subtitle>Enter the spacecraft mass and build a flight path.</:subtitle>
      </.header>

      <.form for={@form} id="mission-form" phx-change="change" phx-submit="change" class="space-y-6">
        <.input
          autocomplete="off"
          field={@form[:mass]}
          inputmode="numeric"
          label="Spacecraft mass (kg)"
          pattern="[0-9]*"
          placeholder="e.g. 28801"
          phx-hook="IntegerOnly"
          required
          type="text"
        />

        <div class="space-y-2">
          <h2 class="font-semibold">Flight path</h2>

          <div id="flight-path" class="space-y-2">
            <p :if={@steps == []} id="empty-flight-path" class="text-sm opacity-60">
              No steps yet. Add one below.
            </p>

            <div
              :for={{step, index} <- Enum.with_index(@steps)}
              id={"step-#{index}"}
              class="flex items-center gap-3"
            >
              <span class="badge badge-neutral w-8">{index + 1}</span>
              <div class="flex-1">
                <.input
                  type="select"
                  id={"step-#{index}-action"}
                  name={"mission[steps][#{index}][action]"}
                  value={step.action}
                  options={@actions}
                />
              </div>
              <div class="flex-1">
                <.input
                  type="select"
                  id={"step-#{index}-planet"}
                  name={"mission[steps][#{index}][planet]"}
                  value={step.planet}
                  options={@planets}
                />
              </div>
              <span id={"step-#{index}-fuel"} class="w-28 mb-2 text-right text-sm tabular-nums">
                {step_fuel(@result, index)}
              </span>
              <button
                type="button"
                id={"remove-step-#{index}"}
                class="btn btn-ghost btn-square btn-sm mb-2"
                phx-click="remove_step"
                phx-value-index={index}
                aria-label="Remove step"
              >
                <.icon name="hero-trash" class="size-4" />
              </button>
            </div>
          </div>

          <ul :if={@path_errors != []} id="flight-path-errors" class="space-y-1">
            <li :for={message <- @path_errors} class="flex items-center gap-2 text-sm text-error">
              <.icon name="hero-exclamation-circle" class="size-4" />
              {message}
            </li>
          </ul>

          <button type="button" id="add-step" class="btn btn-primary btn-soft" phx-click="add_step">
            <.icon name="hero-plus" class="size-4" /> Add step
          </button>
        </div>
      </.form>

      <div id="fuel-result" class="card bg-base-200 mt-8">
        <div class="card-body">
          <h2 class="card-title">Total fuel required</h2>
          <p id="total-fuel" class="text-3xl font-bold">
            {if @result, do: "#{@result.total_fuel} kg", else: "—"}
          </p>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("change", %{"mission" => params}, socket) do
    {:noreply,
     socket
     |> assign(:mass, params["mass"] || "")
     |> assign(:steps, parse_steps(params["steps"]))
     |> recalculate()}
  end

  def handle_event("add_step", _params, socket) do
    {:noreply,
     socket
     |> update(:steps, &(&1 ++ [next_step(List.last(&1))]))
     |> recalculate()}
  end

  def handle_event("remove_step", %{"index" => index}, socket) do
    {:noreply,
     socket
     |> update(:steps, &List.delete_at(&1, String.to_integer(index)))
     |> recalculate()}
  end

  defp recalculate(socket) do
    %{mass: mass, steps: steps} = socket.assigns
    {result, errors} = calculate(mass, steps)
    mass_errors = if errors[:mass], do: [mass: {errors.mass, []}], else: []

    socket
    |> assign(:result, result)
    |> assign(:path_errors, errors |> Map.get(:flight_path, []) |> Enum.flat_map(&Map.values/1))
    |> assign(:form, to_form(%{"mass" => mass}, as: :mission, errors: mass_errors))
  end

  defp calculate("", _steps), do: {nil, %{}}

  defp calculate(mass, steps) do
    flight_path =
      steps
      |> Enum.with_index(1)
      |> Enum.map(fn {step, index} -> Map.put(step, :step_id, index) end)

    case FuelCalculator.fuel_calculator(%{mass: parse_mass(mass), flight_path: flight_path}) do
      {:ok, result} -> {result, %{}}
      {:error, errors} -> {nil, errors}
    end
  end

  defp parse_mass(mass) do
    case Integer.parse(mass) do
      {value, ""} -> value
      _ -> mass
    end
  end

  defp step_fuel(nil, _index), do: "—"
  defp step_fuel(%{steps: steps}, index), do: "#{Enum.at(steps, index).fuel} kg"

  defp parse_steps(nil), do: []

  defp parse_steps(steps) do
    steps
    |> Enum.sort_by(fn {index, _step} -> String.to_integer(index) end)
    |> Enum.map(fn {_index, step} -> %{action: step["action"], planet: step["planet"]} end)
  end

  defp next_step(nil), do: %{action: "launch", planet: "earth"}
  defp next_step(%{action: "launch"}), do: %{action: "land", planet: "moon"}
  defp next_step(%{action: "land", planet: planet}), do: %{action: "launch", planet: planet}
end
