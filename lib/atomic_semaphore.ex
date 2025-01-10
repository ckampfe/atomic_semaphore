defmodule AtomicSemaphore do
  @moduledoc """
  A semaphore structure to limit concurrent access to a shared resource
  by issuing and reclaiming a limited number of "permits".

  ***Note that this implementation is not link-safe.*** That is, if a process
  acquires a permit and exits for some reason, its permit will not be released,
  so be mindful of acquiring permits in processes that can crash or can be
  made to crash because of their links to other processes that can crash.
  """

  @doc """
  Create a new semaphore with `size` available permits.
  """
  @spec new(pos_integer()) :: :atomics.atomics_ref()
  def new(size) when is_integer(size) and size > 0 do
    ref = :atomics.new(1, signed: false)
    :atomics.put(ref, 1, size)
    ref
  end

  @doc """
  Acquire a permit. Blocks until a permit can be acquired.
  Permit must be manually released by calling `release/1`.

  Prefer using `acquire/2` or `acquire/4` as they automatically
  release their permit.
  """
  @spec acquire(:atomics.atomics_ref()) :: :ok
  def acquire(ref) do
    case try_acquire(ref) do
      :ok -> :ok
      {:error, :changed} -> acquire(ref)
      {:error, :no_permits} -> acquire(ref)
    end
  end

  @doc """
  Acquire a permit, call the function `f`, and release the permit.
  Users should prefer this function as it handles the release of
  permits automatically, reducing the chance for error.
  """
  @spec acquire(:atomics.atomics_ref(), (-> any())) :: {:ok, any()}
  def acquire(ref, f) when is_function(f, 0) do
    case acquire(ref) do
      :ok ->
        try do
          {:ok, f.()}
          # TODO is this correct? should it be rescue/catch rather than after?
        after
          release(ref)
        end
    end
  end

  @doc """
  Acquire a permit, call the MFA, and release the permit.
  Users should prefer this function as it handles the release of
  permits automatically, reducing the chance for error.
  """
  @spec acquire(:atomics.atomics_ref(), atom(), atom(), list()) :: {:ok, any()}
  def acquire(ref, m, f, a)
      when is_atom(m) and
             is_atom(f) and
             is_list(a) do
    case acquire(ref) do
      :ok ->
        try do
          {:ok, apply(m, f, a)}
        after
          release(ref)
        end
    end
  end

  @doc """
  Try to acquire a permit, immediately returning `:ok` if a permit has been acquired,
  and `{:error, :no_permits}` if there are no permits available.
  Unlike `acquire`, does not block until a permit is acquired, but will spin in the event of
  the semaphore being access by another process concurrently.

  If this function returns `:ok`, the user must release the given
  permit by calling `release` manually.

  Prefer using `try_acquire/2` or `try_acquire/4` as they automatically
  release their permit.
  """
  @spec try_acquire(:atomics.atomics_ref()) :: :ok | {:error, :changed | :no_permits}
  def try_acquire(ref) do
    expected = :atomics.get(ref, 1)
    desired = expected - 1

    if expected > 0 do
      case :atomics.compare_exchange(ref, 1, expected, desired) do
        :ok ->
          :ok

        _actual ->
          try_acquire(ref)
      end
    else
      {:error, :no_permits}
    end
  end

  @doc """
  Try to acquire a permit and run the function `f`, immediately returning
  `{:ok, f.()}` if a permit has been acquired,
  and `{:error, :no_permits}` if there are no permits available.
  Unlike `acquire`, does not block until a permit is acquired,
  but will spin in the event of the semaphore being access by another process concurrently.

  If `{:error, :no_permits}` is returned, `f` has not been called.
  """
  @spec try_acquire(:atomics.atomics_ref(), (-> any())) ::
          {:ok, any()} | {:error, :changed | :no_permits}
  def try_acquire(ref, f) when is_function(f, 0) do
    expected = :atomics.get(ref, 1)
    desired = expected - 1

    if expected > 0 do
      case :atomics.compare_exchange(ref, 1, expected, desired) do
        :ok ->
          try do
            {:ok, f.()}
            # TODO is this correct? should it be rescue/catch rather than after?
          after
            release(ref)
          end

        _actual ->
          try_acquire(ref, f)
      end
    else
      {:error, :no_permits}
    end
  end

  @doc """
  Try to acquire a permit and run the MFA, immediately returning
  `{:ok, apply(m, f, a)}` if a permit has been acquired,
  and `{:error, :no_permits}` if there are no permits available.
  Unlike `acquire`, does not block until a permit is acquired,
  but will spin in the event of the semaphore being access by another process concurrently.

  If `{:error, :no_permits}` is returned, MFA has not been called.
  """
  @spec try_acquire(:atomics.atomics_ref(), atom(), atom(), list()) ::
          {:ok, any()} | {:error, :changed | :no_permits}
  def try_acquire(ref, m, f, a) when is_atom(m) and is_atom(f) and is_list(a) do
    expected = :atomics.get(ref, 1)
    desired = expected - 1

    if expected > 0 do
      case :atomics.compare_exchange(ref, 1, expected, desired) do
        :ok ->
          try do
            {:ok, apply(m, f, a)}
          after
            release(ref)
          end

        _actual ->
          try_acquire(ref, m, f, a)
      end
    else
      {:error, :no_permits}
    end
  end

  @doc """
  Manually release a permit.

  This function *must* be called after a permit has been acquired
  by `acquire/1` or `try_acquire/1`, otherwise permits will leak.
  """
  @spec release(:atomics.atomics_ref()) :: :ok
  def release(ref) do
    :atomics.add(ref, 1, 1)
  end

  @doc """
  Get the number of currently available permits.
  """
  @spec available_permits(:atomics.atomics_ref()) :: non_neg_integer()
  def available_permits(ref) do
    :atomics.get(ref, 1)
  end
end
