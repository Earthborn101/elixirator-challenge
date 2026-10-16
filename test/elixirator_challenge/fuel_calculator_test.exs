defmodule ElixiratorChallenge.FuelCalculatorTest do
  use ExUnit.Case, async: true

  alias ElixiratorChallenge.FuelCalculator

  defp flight_path(steps) do
    steps
    |> Enum.with_index(1)
    |> Enum.map(fn {{action, planet}, step_id} ->
      %{action: action, planet: planet, step_id: step_id}
    end)
  end

  defp calculate(mass, steps) do
    FuelCalculator.fuel_calculator(%{mass: mass, flight_path: flight_path(steps)})
  end

  describe "example missions" do
    test "Apollo 11" do
      steps = [{"launch", "earth"}, {"land", "moon"}, {"launch", "moon"}, {"land", "earth"}]
      assert {:ok, %{total_fuel: 51_898}} = calculate(28_801, steps)
    end

    test "Mars" do
      steps = [{"launch", "earth"}, {"land", "mars"}, {"launch", "mars"}, {"land", "earth"}]
      assert {:ok, %{total_fuel: 33_388}} = calculate(14_606, steps)
    end

    test "passenger ship" do
      steps = [
        {"launch", "earth"},
        {"land", "moon"},
        {"launch", "moon"},
        {"land", "mars"},
        {"launch", "mars"},
        {"land", "earth"}
      ]

      assert {:ok, %{total_fuel: 212_161}} = calculate(75_432, steps)
    end
  end

  describe "validation" do
    test "rejects a launch from a planet other than the last landing" do
      steps = [{"launch", "earth"}, {"land", "mars"}, {"launch", "earth"}]

      assert {:error, %{flight_path: [%{planet: message}]}} = calculate(14_606, steps)
      assert message =~ "Step 3"
      assert message =~ "mars"
    end

    test "rejects a non-positive mass even when the flight path is valid" do
      assert {:error, %{mass: _}} = calculate(-5, [{"launch", "earth"}])
    end

    test "rejects consecutive steps with the same action" do
      steps = [{"launch", "earth"}, {"launch", "moon"}]
      assert {:error, %{flight_path: [%{action: _}]}} = calculate(1_000, steps)
    end
  end
end
