defmodule Tai.ExchangeAdapters.Gdax.OrderBookFeedTest do
  use ExUnit.Case, async: true
  doctest Tai.ExchangeAdapters.Gdax.OrderBookFeed

  import ExUnit.CaptureLog

  alias Tai.ExchangeAdapters.Gdax.OrderBookFeed
  alias Tai.Markets.OrderBook

  setup do
    {:ok, feed_a_pid} = OrderBookFeed.start_link(
      "ws://localhost:#{EchoBoy.Config.port}/ws",
      feed_id: :feed_a,
      symbols: [:btcusd, :ltcusd]
    )
    {:ok, feed_a_btcusd_pid} = OrderBook.start_link(feed_id: :feed_a, symbol: :btcusd)
    {:ok, feed_a_ltcusd_pid} = OrderBook.start_link(feed_id: :feed_a, symbol: :ltcusd)
    {:ok, feed_b_btcusd_pid} = OrderBook.start_link(feed_id: :feed_b, symbol: :btcusd)

    OrderBook.replace(
      feed_a_btcusd_pid,
      bids: [{1.0, 1.1}, {1.1, 1.0}],
      asks: [{1.2, 0.1}, {1.3, 0.11}]
    )
    OrderBook.replace(
      feed_a_ltcusd_pid,
      bids: [{100.0, 0.1}],
      asks: [{100.1, 0.1}]
    )
    OrderBook.replace(
      feed_b_btcusd_pid,
      bids: [{1.0, 1.1}],
      asks: [{1.2, 0.1}]
    )

    {
      :ok,
      %{
        feed_a_pid: feed_a_pid,
        feed_a_btcusd_pid: feed_a_btcusd_pid,
        feed_a_ltcusd_pid: feed_a_ltcusd_pid,
        feed_b_btcusd_pid: feed_b_btcusd_pid
      }
    }
  end

  test(
    "snapshot replaces the bids/asks in the order book for the symbol",
    %{
      feed_a_pid: feed_a_pid,
      feed_a_btcusd_pid: feed_a_btcusd_pid,
      feed_a_ltcusd_pid: feed_a_ltcusd_pid,
      feed_b_btcusd_pid: feed_b_btcusd_pid
    }
  ) do
    WebSockex.send_frame(
      feed_a_pid,
      {
        :text,
        %{
          type: "snapshot",
          product_id: "BTC-USD",
          bids: [["110.0", "100.0"], ["100.0", "110.0"]],
          asks: [["120.0", "10.0"], ["130.0", "11.0"]]
        } |> JSON.encode!
      }
    )

    :timer.sleep 10
    assert OrderBook.quotes(feed_a_btcusd_pid) == {
      :ok,
      %{
        bids: [[price: 110.0, size: 100.0], [price: 100.0, size: 110.0]],
        asks: [[price: 120.0, size: 10.0], [price: 130.0, size: 11.0]]
      }
    }
    assert OrderBook.quotes(feed_a_ltcusd_pid) == {
      :ok,
      %{
        bids: [[price: 100.0, size: 0.1]],
        asks: [[price: 100.1, size: 0.1]]
      }
    }
    assert OrderBook.quotes(feed_b_btcusd_pid) == {
      :ok,
      %{
        bids: [[price: 1.0, size: 1.1]],
        asks: [[price: 1.2, size: 0.1]]
      }
    }
  end

  test(
    "l2update adds/updates/deletes the bids/asks in the order book for the symbol",
    %{
      feed_a_pid: feed_a_pid,
      feed_a_btcusd_pid: feed_a_btcusd_pid,
      feed_a_ltcusd_pid: feed_a_ltcusd_pid,
      feed_b_btcusd_pid: feed_b_btcusd_pid
    }
  ) do
    WebSockex.send_frame(
      feed_a_pid,
      {
        :text,
        %{
          type: "l2update",
          time: "time not used yet",
          product_id: "BTC-USD",
          changes: [
            ["buy", "0.9", "0.1"],
            ["sell", "1.4", "0.12"],
            ["buy", "1.0", "1.2"],
            ["sell", "1.2", "0.11"],
            ["buy", "1.1", "0"],
            ["sell", "1.3", "0.0"]
          ]
        } |> JSON.encode!
      }
    )

    :timer.sleep 10
    assert OrderBook.quotes(feed_a_btcusd_pid) == {
      :ok,
      %{
        bids: [[price: 1.0, size: 1.2], [price: 0.9, size: 0.1]],
        asks: [[price: 1.2, size: 0.11], [price: 1.4, size: 0.12]]
      }
    }
    assert OrderBook.quotes(feed_a_ltcusd_pid) == {
      :ok,
      %{
        bids: [[price: 100.0, size: 0.1]],
        asks: [[price: 100.1, size: 0.1]]
      }
    }
    assert OrderBook.quotes(feed_b_btcusd_pid) == {
      :ok,
      %{
        bids: [[price: 1.0, size: 1.1]],
        asks: [[price: 1.2, size: 0.1]]
      }
    }
  end

  test "logs a warning for unhandled messages", %{feed_a_pid: feed_a_pid} do
    assert capture_log(fn ->
      WebSockex.send_frame(feed_a_pid, {:text, %{type: "unknown_type"} |> JSON.encode!})
      :timer.sleep 10
    end) =~ "[order_book_feed_feed_a] unhandled message: %{\"type\" => \"unknown_type\"}"
  end
end