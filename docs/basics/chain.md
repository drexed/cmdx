# Basics - Chain

A `Chain` is the ordered trace of every `Result` produced by a top-level task and the subtasks it triggered. It's assembled automatically and gives you one id to correlate an entire execution.

## Structure

A `Chain` is an ordered, mutex-guarded collection of `Result`s. Subtasks `push` onto the chain as they finalize; the root `unshift`s itself last, so the root ends up at index 0 and children follow in completion order.

From a result, reach the chain via:

| Method | Returns |
|--------|---------|
| `result.chain` | The owning `CMDx::Chain` (Enumerable; `id`, `size`, `first`, `last`, etc.) |
| `result.chain.id` | The chain's UUID v7 (`String`) |
| `result.chain_index` | This result's zero-based position in the chain (`Integer`, `nil` if absent) |
| `result.chain_root?` | `true` when this result is the chain's root |
| `CMDx::Chain.current` | The live `Chain` object (only inside execution) |

!!! note

    `result.chain_id` is **not** a method on `Result`—it only appears as a key in `result.to_h`. Use `result.chain.id` to access the UUID.

```ruby
result = ImportDataset.execute(dataset_id: 456)

result.chain.id      #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
result.chain_index   #=> 0
result.chain_root?   #=> true
result.chain.size    #=> 4
result.chain.first   #=> root result (ImportDataset)
result.chain.last    #=> last subtask result

result.chain.each_with_index do |r, idx|
  puts "#{idx}: #{r.task} - #{r.status}"
end
```

The `Chain` instance exposes `id`, `results`, `push` (aliased `<<`), `unshift`, `index`, `size`, `empty?`, `each`, `last`, plus root delegators:

| Method | Returns |
|--------|---------|
| `chain.root` | The result flagged with `root: true`, or `nil` |
| `chain.state` | `chain.root&.state` — `"complete"` / `"interrupted"` / `nil` |
| `chain.status` | `chain.root&.status` — `"success"` / `"skipped"` / `"failed"` / `nil` |

## Subtasks

Subtasks automatically join the current chain, building a unified execution trail:

```ruby
class ImportDataset < CMDx::Task
  def work
    context.dataset = Dataset.find(context.dataset_id)

    result1 = ValidateSchema.execute
    result1.chain.size #=> 1 (the parent hasn't finalized yet)

    result2 = TransformData.execute!(context)
    result2.chain.id == result1.chain.id  #=> true
    result2.chain.size                    #=> 2

    SaveToDatabase.execute(dataset_id: context.dataset_id)
  end
end

# After ImportDataset finalizes, its result is unshifted to position 0:
result = ImportDataset.execute(dataset_id: 456)

result.chain.size                  #=> 4 (parent + 3 subtasks)
result.chain.first.task            #=> ImportDataset (the root)
result.chain.map(&:task)
#=> [ImportDataset, ValidateSchema, TransformData, SaveToDatabase]
```

!!! note

    Chain lifecycle is automatic: Runtime installs a fresh chain when the top-level task starts and clears it on teardown.

## Fiber Storage

The active chain lives on `Fiber[]` (fiber-local), so each `Thread`'s root fiber and every explicit `Fiber.new` sees its own chain. `Workflow` parallel groups intentionally propagate the parent chain into their worker threads so their results roll up under the same trace; the chain's internal mutex makes concurrent pushes safe.

```ruby
# Thread A — its root fiber gets a fresh chain
Thread.new do
  result = ImportDataset.execute(file_path: "/data/batch1.csv")
  result.chain.id    #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
end

# Thread B — completely separate chain
Thread.new do
  result = ImportDataset.execute(file_path: "/data/batch2.csv")
  result.chain.id    #=> "018c2c11-c821-7892-b156-dd7c921fe2a3"
end

# Inspect or clear the current fiber's chain (rarely needed)
CMDx::Chain.current  #=> Returns current chain or nil
CMDx::Chain.clear    #=> Clears current fiber's chain
```
