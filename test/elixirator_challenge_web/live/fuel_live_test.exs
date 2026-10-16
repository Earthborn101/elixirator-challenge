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

  describe "fuel calculation" do
    test "Apollo 11 mission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      submit_mission(view, "28801", [
        {"launch", "earth"},
        {"land", "moon"},
        {"launch", "moon"},
        {"land", "earth"}
      ])

      assert has_element?(view, "#total-fuel", "51898 kg")
      assert has_element?(view, "#step-3-fuel", "13447 kg")
    end

    test "Mars mission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      submit_mission(view, "14606", [
        {"launch", "earth"},
        {"land", "mars"},
        {"launch", "mars"},
        {"land", "earth"}
      ])

      assert has_element?(view, "#total-fuel", "33388 kg")
    end

    test "passenger ship mission", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      submit_mission(view, "75432", [
        {"launch", "earth"},
        {"land", "moon"},
        {"launch", "moon"},
        {"land", "mars"},
        {"launch", "mars"},
        {"land", "earth"}
      ])

      assert has_element?(view, "#total-fuel", "212161 kg")
    end

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

    test "rejects consecutive steps with the same action", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      submit_mission(view, "1000", [{"launch", "earth"}, {"launch", "moon"}])

      assert has_element?(view, "#flight-path-errors")
      assert has_element?(view, "#total-fuel", "—")
    end
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
