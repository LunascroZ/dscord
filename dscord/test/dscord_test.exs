defmodule DscordTest do
  use ExUnit.Case
  doctest Dscord

  test "greets the world" do
    assert Dscord.hello() == :world
  end
end
