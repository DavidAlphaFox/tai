defmodule Tai.Trading.OrderResponses.Amend do
  @moduledoc """
  Return from venue adapters when amending an order
  """

  @type t :: %Tai.Trading.OrderResponses.Amend{
          id: String.t(),
          status: atom,
          price: Decimal.t(),
          leaves_qty: Decimal.t(),
          cumulative_qty: Decimal.t(),
          timestamp: DateTime.t() | nil
        }

  @enforce_keys [
    :id,
    :status,
    :price,
    :leaves_qty,
    :cumulative_qty
  ]
  defstruct [
    :id,
    :status,
    :price,
    :leaves_qty,
    :cumulative_qty,
    :timestamp
  ]
end
