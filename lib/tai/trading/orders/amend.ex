defmodule Tai.Trading.Orders.Amend do
  alias Tai.Trading.Orders

  @type order :: Tai.Trading.Order.t()
  @type attrs :: %{
          optional(:price) => Decimal.t(),
          optional(:qty) => Decimal.t()
        }

  @spec amend(order, attrs) ::
          {:ok, updated_order :: order} | {:error, :order_status_must_be_open}
  def amend(order, attrs) when is_map(attrs) do
    with {:ok, {old_order, updated_order}} <- find_open_order_and_pend_amend(order.client_id) do
      Orders.updated!(old_order, updated_order)

      Task.start_link(fn ->
        updated_order
        |> send_amend_order(attrs)
        |> parse_response(updated_order.client_id, attrs)
      end)

      {:ok, updated_order}
    else
      {:error, :not_found} -> handle_invalid_status(order.client_id)
    end
  end

  defp send_amend_order(order, attrs), do: Tai.Venue.amend_order(order, attrs)

  defp parse_response({:ok, _order_response}, client_id, attrs) do
    {:ok, {old_order, updated_order}} = find_pending_amend_order_and_open(client_id, attrs)
    Orders.updated!(old_order, updated_order)
  end

  defp parse_response({:error, reason}, client_id, _attrs) do
    {:ok, {old_order, updated_order}} = find_pending_amend_order_and_error(client_id, reason)
    Orders.updated!(old_order, updated_order)
  end

  defp find_open_order_and_pend_amend(client_id) do
    Tai.Trading.OrderStore.find_by_and_update(
      [client_id: client_id, status: :open],
      status: :pending_amend
    )
  end

  defp find_pending_amend_order_and_open(client_id, attrs) do
    update_attrs =
      attrs
      |> to_order_attrs
      |> Keyword.put(:status, :open)

    Tai.Trading.OrderStore.find_by_and_update(
      [client_id: client_id, status: :pending_amend],
      update_attrs
    )
  end

  defp find_pending_amend_order_and_error(client_id, reason) do
    Tai.Trading.OrderStore.find_by_and_update(
      [client_id: client_id, status: :pending_amend],
      status: :error,
      error_reason: reason
    )
  end

  defp handle_invalid_status(client_id) do
    {:ok, order} = Tai.Trading.OrderStore.find(client_id)

    Tai.Events.broadcast(%Tai.Events.OrderErrorAmendHasInvalidStatus{
      client_id: client_id,
      was: order.status,
      required: :open
    })

    {:error, :order_status_must_be_open}
  end

  defp to_order_attrs(attrs) when is_map(attrs) do
    attrs
    |> Map.to_list()
    |> to_order_attrs
  end

  defp to_order_attrs(attrs) when is_list(attrs), do: [] |> to_order_attrs(attrs)

  defp to_order_attrs(update_attrs, []), do: update_attrs

  defp to_order_attrs(update_attrs, [{:price, price} | tail]) do
    update_attrs
    |> Keyword.put(:price, price)
    |> to_order_attrs(tail)
  end

  defp to_order_attrs(update_attrs, [{:qty, leaves_qty} | tail]) do
    update_attrs
    |> Keyword.put(:leaves_qty, leaves_qty)
    |> to_order_attrs(tail)
  end
end
