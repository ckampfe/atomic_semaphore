defmodule AtomicSemaphoreTest do
  use ExUnit.Case
  doctest AtomicSemaphore

  test "try_acquire/1" do
    s = AtomicSemaphore.new(1)
    assert 1 == AtomicSemaphore.available_permits(s)
    assert :ok == AtomicSemaphore.try_acquire(s)
    assert 0 == AtomicSemaphore.available_permits(s)
    assert {:error, :no_permits} == AtomicSemaphore.try_acquire(s)
    assert 0 == AtomicSemaphore.available_permits(s)
    assert :ok == AtomicSemaphore.release(s)
    assert 1 == AtomicSemaphore.available_permits(s)
  end

  test "try_acquire/2" do
    s = AtomicSemaphore.new(1)
    assert 1 == AtomicSemaphore.available_permits(s)

    assert {:ok, "hello"} ==
             AtomicSemaphore.try_acquire(s, fn ->
               # we have the semaphore here
               assert 0 == AtomicSemaphore.available_permits(s)
               "hello"
             end)

    assert 1 == AtomicSemaphore.available_permits(s)

    AtomicSemaphore.acquire(s)

    assert {:error, :no_permits} ==
             AtomicSemaphore.try_acquire(s, fn ->
               # we have the semaphore here
               assert 0 == AtomicSemaphore.available_permits(s)
               "hello"
             end)
  end

  test "try_acquire/4" do
    s = AtomicSemaphore.new(1)
    assert 1 == AtomicSemaphore.available_permits(s)

    assert {:ok, 3} ==
             AtomicSemaphore.try_acquire(s, __MODULE__, :add, [s, 1, 2])

    assert 1 == AtomicSemaphore.available_permits(s)

    AtomicSemaphore.acquire(s)

    assert {:error, :no_permits} ==
             AtomicSemaphore.try_acquire(s, __MODULE__, :add, [s, 1, 2])
  end

  test "acquire/1" do
    s = AtomicSemaphore.new(1)
    assert 1 == AtomicSemaphore.available_permits(s)
    assert :ok == AtomicSemaphore.acquire(s)
    assert 0 == AtomicSemaphore.available_permits(s)
    assert :ok == AtomicSemaphore.release(s)
    assert 1 == AtomicSemaphore.available_permits(s)
  end

  test "acquire/2" do
    s = AtomicSemaphore.new(1)
    assert 1 == AtomicSemaphore.available_permits(s)

    assert {:ok, "hello"} ==
             AtomicSemaphore.acquire(s, fn ->
               # we have the semaphore here
               assert 0 == AtomicSemaphore.available_permits(s)
               "hello"
             end)

    assert 1 == AtomicSemaphore.available_permits(s)
  end

  test "acquire/4" do
    s = AtomicSemaphore.new(1)
    assert 1 == AtomicSemaphore.available_permits(s)

    assert {:ok, 3} ==
             AtomicSemaphore.acquire(s, __MODULE__, :add, [s, 1, 2])

    assert 1 == AtomicSemaphore.available_permits(s)
  end

  test "permits" do
    :ets.new(:semaphore_permits_test, [:named_table, :public, :set])
    :ets.insert(:semaphore_permits_test, {:permits, 0})

    s = AtomicSemaphore.new(10)

    Enum.each(1..20, fn _i ->
      spawn(fn ->
        AtomicSemaphore.acquire(s, fn ->
          :ets.update_counter(:semaphore_permits_test, :permits, 1)
          :timer.sleep(50)
        end)
      end)
    end)

    :timer.sleep(25)
    assert :ets.lookup_element(:semaphore_permits_test, :permits, 2) == 10
    :timer.sleep(25)
    assert :ets.lookup_element(:semaphore_permits_test, :permits, 2) == 20
  end

  test "available_permits/1" do
    n = :rand.uniform(20)
    s = AtomicSemaphore.new(n)
    assert AtomicSemaphore.available_permits(s) == n
    m = :rand.uniform(n)

    Enum.each(1..m, fn _ ->
      AtomicSemaphore.acquire(s)
    end)

    assert AtomicSemaphore.available_permits(s) == n - m
  end

  def add(s, a, b) do
    assert 0 == AtomicSemaphore.available_permits(s)
    a + b
  end
end
