defmodule Tai.TestSupport.Factories.Order do
  def build_invalid_order(callback \\ nil) do
    %Tai.Trading.Order{
      side: :invalid_side,
      type: :invalid_type,
      client_id: :ignore,
      enqueued_at: :ignore,
      exchange_id: :ignore,
      account_id: :ignore,
      price: :ignore,
      avg_price: :ignore,
      qty: :ignore,
      leaves_qty: :ignore,
      cumulative_qty: :ignore,
      status: :enqueued,
      symbol: :ignore,
      time_in_force: :ignore,
      post_only: false,
      order_updated_callback: callback
    }
  end
end
