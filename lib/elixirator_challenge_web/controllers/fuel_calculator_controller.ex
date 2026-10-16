defmodule ElixiratorChallengeWeb.FuelController do
  use ElixiratorChallengeWeb, :controller

  alias ElixiratorChallenge.FuelCalculator

  def calculate(conn, params) do
    mass = params["mass"]
    flight_path = params["flight_path"]

    case FuelCalculator.fuel_calculator(%{
           mass: mass,
           flight_path:
             flight_path
             |> Enum.with_index(1)
             |> Enum.map(fn {step, index} ->
               %{action: step["action"], planet: step["planet"], step_id: index}
             end)
         }) do
      {:ok, result} ->
        json(conn, result)

      {:error, message} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: message})
    end
  end
end
