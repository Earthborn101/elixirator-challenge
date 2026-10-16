defmodule ElixiratorChallenge.FuelCalculator do
  @moduledoc """
  Calculates fuel requirements for multi-step spacecraft journeys.
  """

  @planets %{
    "earth" => 9.807,
    "mars" => 3.711,
    "moon" => 1.62
  }

  @type args :: %{
          flight_path: list(step()),
          mass: integer()
        }

  @type step :: %{
          action: String.t(),
          planet: String.t(),
          step_id: integer()
        }

  @type result :: %{
          steps: list(calculated_step()),
          total_fuel: integer()
        }

  @type calculated_step :: %{
          action: String.t(),
          fuel: integer(),
          planet: String.t()
        }

  @spec fuel_calculator(args()) :: {:ok, result()} | {:error, map()}
  def fuel_calculator(params) do
    return_result =
      params
      |> validate()
      |> calculate()

    case return_result do
      {:ok, calculated_fuel} ->
        {:ok, calculated_fuel}

      {:error, errors} ->
        {:error, errors}
    end
  end

  @spec validate(args()) :: {:ok, args()} | {:error, map()}
  defp validate(params) do
    return_result =
      {:ok, params, %{}}
      |> validate_mass()
      |> validate_flight_path()

    case return_result do
      {:ok, params, _errors} ->
        {:ok, params}

      {:error, _params, errors} ->
        {:error, errors}
    end
  end

  @spec validate_mass({:ok, args(), map()}) :: {:ok, args(), map()} | {:error, args(), map()}
  defp validate_mass({:ok, %{mass: mass}, _errors} = params) when is_integer(mass) and mass > 0 do
    params
  end

  defp validate_mass({:ok, params, errors}) do
    {:error, params, Map.put(errors, :mass, "Mass should be an integer and greater than 0kg.")}
  end

  @spec validate_flight_path({atom(), args(), map()}) ::
          {:ok, args(), map()} | {:error, args(), map()}
  defp validate_flight_path({_, %{flight_path: []}, _errors} = params) do
    params
  end

  defp validate_flight_path({status, %{flight_path: flight_path} = params, errors})
       when is_list(flight_path) do
    return_result =
      flight_path
      |> Enum.reduce({[], []}, fn step_params, {steps, error_steps} ->
        return_result =
          {:ok, step_params, %{}}
          |> validate_step_id(steps)
          |> validate_step_action(steps)
          |> validate_step_planet()
          |> validate_step_location(steps)

        case return_result do
          {:ok, step_params, _} ->
            {steps ++ [step_params], error_steps}

          {:error, step_params, error_map} ->
            {steps ++ [step_params], error_steps ++ [error_map]}
        end
      end)

    case return_result do
      {_step_list, []} ->
        {status, params, errors}

      {_step_list, error_steps} ->
        {:error, params, Map.put(errors, :flight_path, error_steps)}
    end
  end

  defp validate_step_id({:ok, %{step_id: step_id} = params, errors} = step_params, steps) do
    previous_step = List.last(steps)

    if step_id != previous_step[:step_id] do
      step_params
    else
      {:error, params,
       Map.put(errors, :step_id, "Invalid id. It must not have any duplicate step id.")}
    end
  end

  defp validate_step_action({:ok, %{action: action, step_id: _}, _errors} = step_params, steps)
       when action in ["launch", "land"] do
    validate_step_action_no_duplicate_action_in_previous_step(step_params, steps)
  end

  defp validate_step_action({:ok, %{step_id: id} = params, errors}, _steps) when is_integer(id) do
    {:error, params,
     Map.put(errors, :action, "Step #{id} has an invalid action. It's must be launch or land.")}
  end

  defp validate_step_action({:error, _, _} = step_params, _steps) do
    step_params
  end

  defp validate_step_action_no_duplicate_action_in_previous_step(params, []) do
    params
  end

  defp validate_step_action_no_duplicate_action_in_previous_step(
         {_, %{action: action, step_id: step_id} = params, errors} = step_params,
         steps
       ) do
    previous_step = List.last(steps)

    case action != previous_step[:action] do
      true ->
        step_params

      false ->
        {:error, params,
         errors
         |> Map.put(
           :action,
           "Step #{step_id} has an invalid action. Actions must alternate between launch and land"
         )}
    end
  end

  defp validate_step_planet(
         {:ok, %{step_id: step_id, planet: planet} = params, errors} = step_params
       ) do
    case Map.has_key?(@planets, planet) do
      true ->
        step_params

      false ->
        {:error, params,
         Map.put(
           errors,
           :planet,
           "Step #{step_id} has an invalid planet. Planet must be earth, moon, or mars."
         )}
    end
  end

  defp validate_step_planet({:ok, %{step_id: step_id} = params, errors}) do
    {:error, params,
     Map.put(
       errors,
       :planet,
       "Step #{step_id} has an invalid planet. Planet must be earth, moon, or mars."
     )}
  end

  defp validate_step_planet({:error, _, _} = step_params) do
    step_params
  end

  defp validate_step_location(
         {:ok, %{action: "launch", planet: planet, step_id: step_id} = params, errors} =
           step_params,
         steps
       ) do
    case List.last(steps) do
      %{action: "land", planet: landed_planet} when landed_planet != planet ->
        {:error, params,
         Map.put(
           errors,
           :planet,
           "Step #{step_id} has an invalid planet. The spacecraft must launch from #{landed_planet}, where it last landed."
         )}

      _ ->
        step_params
    end
  end

  defp validate_step_location(step_params, _steps) do
    step_params
  end

  @spec calculate({:ok, args()} | {:error, map()}) :: {:ok, result()} | {:error, map()}
  defp calculate({:error, _errors} = errors), do: errors

  defp calculate({:ok, %{mass: mass, flight_path: flight_path}}) do
    return_result =
      flight_path
      |> Enum.reverse()
      |> Enum.reduce({0, mass, []}, fn step, {total, current_mass, results} ->
        gravity = Map.fetch!(@planets, step.planet)
        fuel = stage_fuel(current_mass, gravity, step.action)

        result = %{
          action: step.action,
          planet: step.planet,
          fuel: fuel
        }

        {total + fuel, current_mass + fuel, [result | results]}
      end)
      |> then(fn {total, _mass, results} -> %{total_fuel: total, steps: results} end)

    {:ok, return_result}
  end

  @spec stage_fuel(integer(), float(), String.t()) :: integer()
  defp stage_fuel(mass, gravity, action) do
    {factor, offset} =
      case action do
        "launch" -> {0.042, 33}
        "land" -> {0.033, 42}
      end

    calculate_recursive(mass, gravity, factor, offset)
  end

  defp calculate_recursive(mass, gravity, factor, offset) do
    fuel = max(floor(mass * gravity * factor - offset), 0)

    if fuel > 0 do
      fuel + calculate_recursive(fuel, gravity, factor, offset)
    else
      0
    end
  end
end
