# Elixirator Challenge: Interplanetary Fuel Calculator

A Phoenix LiveView app that calculates the fuel a spacecraft needs to fly a
flight path of launches and landings between Earth, the Moon and Mars. The total
updates live as you edit the mass or the flight path.

## Important details

- **No database.** The app doesn't use Ecto or Postgres, so there's nothing to
  create or migrate. Each browser tab keeps its mission in the LiveView's
  memory, and reloading the page starts over.
- **No JSON API.** The calculator is used only by the LiveView page.
- **No sign-in.** The calculator is the home page at `/`.
- **Supported planets:** Earth (gravity 9.807), Moon (1.62), Mars (3.711).

## Requirements

- Elixir `~> 1.17` with a matching Erlang/OTP version. Developed with
  Elixir 1.18.2 on OTP 27.
- No Node.js needed. Tailwind and esbuild are downloaded by `mix setup`.

## Getting started

```sh
git clone https://github.com/Earthborn101/elixirator-challenge.git
cd elixirator-challenge
mix setup        # fetch deps, install and build assets
mix phx.server   # or: iex -S mix phx.server
```

Then open [http://localhost:4000](http://localhost:4000).

## Using the calculator

1. **Enter the spacecraft mass** in kilograms. The field only accepts whole
   numbers: non-digit characters are removed as you type or paste.
2. **Build the flight path.** The first step starts as *Launch – Earth*.
   - Choose the action (*Launch* or *Land*) and the planet for each step.
   - Click **Add step** to add a step. It suggests the next logical step: a
     landing after a launch, or a launch from the planet you just landed on.
   - Click the trash icon to remove a step.
3. **Read the results.** The fuel for each step appears next to it, and the
   **Total fuel required** card shows the sum. Both update on every change.
   Pressing Enter doesn't submit or reload the page.

If the input is invalid, the total shows "—". A mass error appears under the
mass field, and step errors are listed under the flight path. Each error names
its step, for example *"Step 3 has an invalid planet. The spacecraft must
launch from mars, where it last landed."*

### Validation rules

| Input | Rule |
| --- | --- |
| Mass | Must be a whole number greater than 0. |
| Action | Must be `launch` or `land`. |
| Action order | Must alternate: no two launches or two landings in a row. |
| Planet | Must be Earth, Moon or Mars. |
| Launch planet | A launch after a landing must leave from the planet the ship landed on. |

The page doesn't show errors until a mass is entered, so an empty form isn't
shown as an error.

## How the fuel is calculated

Each step uses one of these formulas, rounded down:

- **Launch:** `mass * gravity * 0.042 - 33`
- **Landing:** `mass * gravity * 0.033 - 42`

The fuel itself has mass, so the same formula is applied again to the fuel just
added, repeating until the result is 0 or negative. Landing 28801 kg on Earth
needs `9278 + 2960 + 915 + 254 + 40 = 13447` kg of fuel.

Steps are calculated **from the last step back to the first**. When the ship
takes off, it has to carry the fuel for every later step, so each step's mass
is the spacecraft mass plus the fuel for all the steps after it.

### Example scenarios

| Mission | Flight path | Mass | Total fuel |
| --- | --- | --- | --- |
| Apollo 11 | launch Earth, land Moon, launch Moon, land Earth | 28801 kg | 51898 kg |
| Mars | launch Earth, land Mars, launch Mars, land Earth | 14606 kg | 33388 kg |
| Passenger ship | launch Earth, land Moon, launch Moon, land Mars, launch Mars, land Earth | 75432 kg | 212161 kg |

## Project structure

| Path | Purpose |
| --- | --- |
| `lib/elixirator_challenge/fuel_calculator.ex` | Validation and fuel calculation. Pure functions with no web or process code. |
| `lib/elixirator_challenge_web/live/fuel_live.ex` | The LiveView: form, flight-path editing and result display. |
| `assets/js/app.js` | Registers the `IntegerOnly` hook, which removes non-digits from the mass field as you type. |
| `test/elixirator_challenge/fuel_calculator_test.exs` | Calculator tests: example scenarios, per-step fuel, and every error. |
| `test/elixirator_challenge_web/live/fuel_live_test.exs` | LiveView tests that use the page like a user: enter the mass, build the path, check results and errors. |

### Calculator API

```elixir
ElixiratorChallenge.FuelCalculator.fuel_calculator(%{
  mass: 28_801,
  flight_path: [
    %{step_id: 1, action: "launch", planet: "earth"},
    %{step_id: 2, action: "land", planet: "moon"},
    %{step_id: 3, action: "launch", planet: "moon"},
    %{step_id: 4, action: "land", planet: "earth"}
  ]
})
#=> {:ok,
#    %{
#      total_fuel: 51898,
#      steps: [
#        %{action: "launch", planet: "earth", fuel: 32988},
#        %{action: "land", planet: "moon", fuel: 2462},
#        %{action: "launch", planet: "moon", fuel: 3001},
#        %{action: "land", planet: "earth", fuel: 13447}
#      ]
#    }}
```

Invalid input returns `{:error, errors}`, where `errors` can have two keys:

- `:mass`: a single message string.
- `:flight_path`: a list with one error map for each invalid step, such as
  `%{action: "..."}`. Valid steps aren't included.

Mass and flight path errors are returned together, and each step reports only
its first failing check.

## Running the tests

```sh
mix test        # run the test suite
mix precommit   # compile with warnings as errors, unlock unused deps, format, and test
```
