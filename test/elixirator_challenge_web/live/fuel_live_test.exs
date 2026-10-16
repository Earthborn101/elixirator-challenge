defmodule ElixiratorChallengeWeb.FuelLiveTest do
  use ElixiratorChallengeWeb.ConnCase

  import Phoenix.LiveViewTest

  test "renders the mission form", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    assert has_element?(view, "#mission-form")
    assert has_element?(view, "#step-0")
    assert has_element?(view, "#total-fuel")
  end

  test "adds and removes flight path steps", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    view |> element("#add-step") |> render_click()
    assert has_element?(view, "#step-1")

    view |> element("#remove-step-1") |> render_click()
    view |> element("#remove-step-0") |> render_click()
    refute has_element?(view, "#step-0")
    assert has_element?(view, "#empty-flight-path")
  end

  test "pressing enter keeps the mission on the page", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/")

    enter_mass(view, "28801")
    total_before = view |> element("#total-fuel") |> render()
    refute total_before =~ "—"

    view |> form("#mission-form") |> render_submit()

    assert view |> element("#total-fuel") |> render() == total_before
  end

  describe "example scenarios" do
    test "Apollo 11 mission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      enter_mass(view, "28801")

      build_flight_path(view, [
        {"launch", "earth"},
        {"land", "moon"},
        {"launch", "moon"},
        {"land", "earth"}
      ])

      assert_step_fuel(view, ["32988 kg", "2462 kg", "3001 kg", "13447 kg"])
      assert has_element?(view, "#total-fuel", "51898 kg")
    end

    test "Mars mission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      enter_mass(view, "14606")

      build_flight_path(view, [
        {"launch", "earth"},
        {"land", "mars"},
        {"launch", "mars"},
        {"land", "earth"}
      ])

      assert_step_fuel(view, ["19533 kg", "3360 kg", "3806 kg", "6689 kg"])
      assert has_element?(view, "#total-fuel", "33388 kg")
    end

    test "passenger ship mission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      enter_mass(view, "75432")

      build_flight_path(view, [
        {"launch", "earth"},
        {"land", "moon"},
        {"launch", "moon"},
        {"land", "mars"},
        {"launch", "mars"},
        {"land", "earth"}
      ])

      assert_step_fuel(view, [
        "118155 kg",
        "8951 kg",
        "10818 kg",
        "18177 kg",
        "20356 kg",
        "35704 kg"
      ])

      assert has_element?(view, "#total-fuel", "212161 kg")
    end
  end

  describe "fuel calculation errors" do
    test "rejects a non-positive mass", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html = submit_mission(view, "-5", [{"launch", "earth"}])

      assert has_element?(view, "#total-fuel", "—")
      assert html =~ "Mass should be an integer"
    end

    test "rejects a mass that is not a whole number", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      html = submit_mission(view, "2000e", [{"launch", "earth"}])

      assert has_element?(view, "#total-fuel", "—")
      assert html =~ "Mass should be an integer"
    end
  end

  describe "invalid steps" do
    test "shows an error for consecutive steps with the same action", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      enter_mass(view, "28801")
      build_flight_path(view, [{"launch", "earth"}, {"launch", "moon"}])

      assert_step_errors(view, [
        "Step 2 has an invalid action. Actions must alternate between launch and land"
      ])
    end

    test "shows an error for a launch from a planet other than the last landing", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      enter_mass(view, "14606")
      build_flight_path(view, [{"launch", "earth"}, {"land", "mars"}, {"launch", "earth"}])

      assert_step_errors(view, [
        "Step 3 has an invalid planet. The spacecraft must launch from mars, where it last landed."
      ])
    end

    test "shows an error for every invalid step", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      enter_mass(view, "28801")

      build_flight_path(view, [
        {"launch", "earth"},
        {"launch", "moon"},
        {"land", "mars"},
        {"launch", "earth"}
      ])

      assert_step_errors(view, [
        "Step 2 has an invalid action. Actions must alternate between launch and land",
        "Step 4 has an invalid planet. The spacecraft must launch from mars, where it last landed."
      ])
    end

    test "shows step errors once a mass is entered after the flight path", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      build_flight_path(view, [{"launch", "earth"}, {"launch", "moon"}])
      refute has_element?(view, "#flight-path-errors")

      enter_mass(view, "28801")

      assert_step_errors(view, [
        "Step 2 has an invalid action. Actions must alternate between launch and land"
      ])
    end

    test "clears the error once the step is fixed", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      enter_mass(view, "28801")
      build_flight_path(view, [{"launch", "earth"}, {"launch", "moon"}])
      assert has_element?(view, "#flight-path-errors")

      set_step(view, 1, "land", "moon")

      refute has_element?(view, "#flight-path-errors")
      refute has_element?(view, "#total-fuel", "—")
    end

    test "shows errors for actions and planets that are not in the options", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      submit_mission(view, "28801", [{"fly", "earth"}, {"land", "pluto"}])

      assert_step_errors(view, [
        "Step 1 has an invalid action. It must be launch or land.",
        "Step 2 has an invalid planet. Planet must be earth, moon, or mars."
      ])
    end
  end

  defp assert_step_errors(view, messages) do
    rendered_messages =
      view
      |> element("#flight-path-errors")
      |> render()
      |> LazyHTML.from_fragment()
      |> LazyHTML.query("li")
      |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))

    assert rendered_messages == messages
    assert has_element?(view, "#total-fuel", "—")
  end

  defp enter_mass(view, mass) do
    view
    |> form("#mission-form", %{"mission" => %{"mass" => mass}})
    |> render_change()
  end

  defp build_flight_path(view, steps) do
    steps
    |> Enum.with_index()
    |> Enum.each(fn {{action, planet}, index} ->
      if index > 0, do: view |> element("#add-step") |> render_click()
      set_step(view, index, action, planet)
    end)

    refute has_element?(view, "#step-#{length(steps)}")
  end

  defp set_step(view, index, action, planet) do
    view
    |> form("#mission-form", %{
      "mission" => %{"steps" => %{"#{index}" => %{"action" => action, "planet" => planet}}}
    })
    |> render_change()
  end

  defp assert_step_fuel(view, expected_fuel) do
    expected_fuel
    |> Enum.with_index()
    |> Enum.each(fn {fuel, index} ->
      assert has_element?(view, "#step-#{index}-fuel", fuel)
    end)
  end

  defp submit_mission(view, mass, steps) do
    steps =
      steps
      |> Enum.with_index()
      |> Map.new(fn {{action, planet}, index} ->
        {to_string(index), %{"action" => action, "planet" => planet}}
      end)

    view
    |> element("#mission-form")
    |> render_change(%{"mission" => %{"mass" => mass, "steps" => steps}})
  end
end
