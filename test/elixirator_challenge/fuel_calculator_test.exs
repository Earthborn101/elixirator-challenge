defmodule ElixiratorChallenge.FuelCalculatorTest do
  use ExUnit.Case, async: true

  alias ElixiratorChallenge.FuelCalculator

  @mass_error "Mass should be an integer and greater than 0kg."

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

  defp assert_mission(mass, steps, expected_total, expected_step_fuel) do
    assert {:ok, %{total_fuel: total_fuel, steps: calculated_steps}} = calculate(mass, steps)

    assert total_fuel == expected_total
    assert Enum.map(calculated_steps, & &1.fuel) == expected_step_fuel
    assert Enum.sum(expected_step_fuel) == expected_total

    assert Enum.map(calculated_steps, &{&1.action, &1.planet}) == steps
  end

  describe "example scenarios" do
    test "landing Apollo 11 CSM on Earth includes fuel for the fuel" do
      assert_mission(28_801, [{"land", "earth"}], 13_447, [13_447])
    end

    test "apollo 11 mission" do
      steps = [{"launch", "earth"}, {"land", "moon"}, {"launch", "moon"}, {"land", "earth"}]

      assert_mission(28_801, steps, 51_898, [32_988, 2_462, 3_001, 13_447])
    end

    test "mars mission" do
      steps = [{"launch", "earth"}, {"land", "mars"}, {"launch", "mars"}, {"land", "earth"}]

      assert_mission(14_606, steps, 33_388, [19_533, 3_360, 3_806, 6_689])
    end

    test "passenger ship mission" do
      steps = [
        {"launch", "earth"},
        {"land", "moon"},
        {"launch", "moon"},
        {"land", "mars"},
        {"launch", "mars"},
        {"land", "earth"}
      ]

      assert_mission(75_432, steps, 212_161, [118_155, 8_951, 10_818, 18_177, 20_356, 35_704])
    end
  end

  describe "an empty flight path" do
    test "is valid and requires no fuel" do
      assert {:ok, %{total_fuel: 0, steps: []}} = calculate(28_801, [])
    end
  end

  describe "mass errors" do
    for {label, mass} <- [
          zero: 0,
          negative: -5,
          float: 1.5,
          string: "28801",
          nil: nil
        ] do
      test "rejects #{label} mass" do
        assert {:error, %{mass: @mass_error} = errors} =
                 calculate(unquote(Macro.escape(mass)), [{"launch", "earth"}])

        refute Map.has_key?(errors, :flight_path)
      end
    end

    test "is reported even when the flight path is empty" do
      assert {:error, %{mass: @mass_error}} = calculate(0, [])
    end
  end

  describe "flight path errors" do
    test "rejects an unknown action" do
      assert {:error, errors} = calculate(1_000, [{"fly", "earth"}])

      assert errors == %{
               flight_path: [
                 %{action: "Step 1 has an invalid action. It must be launch or land."}
               ]
             }
    end

    test "rejects consecutive steps with the same action" do
      assert {:error, errors} = calculate(1_000, [{"launch", "earth"}, {"launch", "moon"}])

      assert errors == %{
               flight_path: [
                 %{
                   action:
                     "Step 2 has an invalid action. Actions must alternate between launch and land"
                 }
               ]
             }
    end

    test "rejects an unknown planet" do
      assert {:error, errors} = calculate(1_000, [{"launch", "pluto"}])

      assert errors == %{
               flight_path: [
                 %{planet: "Step 1 has an invalid planet. Planet must be earth, moon, or mars."}
               ]
             }
    end

    test "rejects a launch from a planet other than the last landing" do
      steps = [{"launch", "earth"}, {"land", "mars"}, {"launch", "earth"}]

      assert {:error, errors} = calculate(14_606, steps)

      assert errors == %{
               flight_path: [
                 %{
                   planet:
                     "Step 3 has an invalid planet. The spacecraft must launch from mars, where it last landed."
                 }
               ]
             }
    end

    test "rejects consecutive duplicate step ids" do
      flight_path = [
        %{action: "launch", planet: "earth", step_id: 1},
        %{action: "land", planet: "moon", step_id: 1}
      ]

      assert {:error, errors} =
               FuelCalculator.fuel_calculator(%{mass: 1_000, flight_path: flight_path})

      assert errors == %{
               flight_path: [%{step_id: "Invalid id. It must not have any duplicate step id."}]
             }
    end

    test "reports only the first failing check of a step" do
      assert {:error, %{flight_path: [step_errors]}} = calculate(1_000, [{"fly", "pluto"}])

      assert Map.keys(step_errors) == [:action]
    end

    test "lists only invalid steps, in flight path order" do
      steps = [
        {"launch", "earth"},
        {"land", "pluto"},
        {"land", "moon"},
        {"launch", "moon"}
      ]

      assert {:error, %{flight_path: [step_2, step_3]}} = calculate(1_000, steps)

      assert step_2.planet =~ "Step 2"
      assert step_3.action =~ "Step 3"
    end
  end

  describe "combined errors" do
    test "returns mass and flight path errors together" do
      steps = [{"launch", "earth"}, {"launch", "pluto"}, {"fly", "moon"}]

      assert {:error, errors} = calculate(-1, steps)

      assert errors == %{
               mass: @mass_error,
               flight_path: [
                 %{
                   action:
                     "Step 2 has an invalid action. Actions must alternate between launch and land"
                 },
                 %{action: "Step 3 has an invalid action. It must be launch or land."}
               ]
             }
    end
  end
end
