# Basics - Chain

A **`Chain`** is the playlist of every `Result` from one top-level task run — the parent plus every subtask it kicked off — in order. CMDx builds it for you so you get **one id** to grep in logs and tie the whole story together.

## Structure

Under the hood it’s an ordered list (thread-safe). Subtasks **append** as they finish; the root **prepends** itself at the end, so index `0` is always the root task and the rest follow in completion order.

Handy accessors from any `Result`:

| Method                | What it is                                                                                               |
| --------------------- | -------------------------------------------------------------------------------------------------------- |
| `result.chain`        | The `CMDx::Chain` (Enumerable — `id`, `size`, `first`, `last`, …)                                        |
| `result.cid`          | This chain’s UUID v7 (`String`)                                                                          |
| `result.xid`          | External correlation id (`String`, or `nil` if you didn’t configure a resolver)                          |
| `result.index`        | This result’s position in the chain (`Integer`, or `nil` if it never joined — rare outside test doubles) |
| `result.root?`        | `true` if this result is the root                                                                        |
| `CMDx::Chain.current` | The live chain **during** execution only                                                                 |

```ruby
result = ImportDataset.execute(dataset_id: 456)

result.cid           #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
result.index         #=> 0
result.root?         #=> true
result.chain.size    #=> 4
result.chain.first   #=> root result (ImportDataset)
result.chain.last    #=> last subtask result

result.chain.each_with_index do |r, idx|
  puts "#{idx}: #{r.task} - #{r.status}"
end
```

On the `Chain` object itself you’ll also see `id`, `xid`, `results`, `push` (aka `<<`), `unshift`, `index`, `size`, `empty?`, `each`, `last`, plus shortcuts:

| Method         | What it is                                                            |
| -------------- | --------------------------------------------------------------------- |
| `chain.root`   | The result marked `root: true`, or `nil`                              |
| `chain.state`  | `chain.root&.state` — `"complete"` / `"interrupted"` / `nil`          |
| `chain.status` | `chain.root&.status` — `"success"` / `"skipped"` / `"failed"` / `nil` |

## Subtasks

Call another task from inside `work`? Its result joins **the same chain** automatically — one trace end to end.

```ruby
class ImportDataset < CMDx::Task
  def work
    context.dataset = Dataset.find(context.dataset_id)

    result1 = ValidateSchema.execute(context)
    result1.chain.size #=> 1 (the parent hasn't finalized yet)

    result2 = TransformData.execute!(context)
    result2.cid == result1.cid            #=> true
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

Note

You don’t manage chain lifecycle by hand: a fresh chain starts with the root task, everything freezes on teardown, and the fiber-local pointer clears. `result.index` is only `nil` for results that never made it onto a chain — in real runs, finalized results are always on theirs.

## Correlation ID (xid)

`cid` = “this execution.” `xid` = “this **external** request / trace id” (think Rails `request_id`). They’re different on purpose.

`xid` is resolved **once** when the root chain is created, from `CMDx.configuration.correlation_id` (a proc), or per-task via `settings(correlation_id: -> { ... })`. Every nested task shares that same `xid` through the chain — one id in logs for the whole tree.

```ruby
CMDx.configure do |config|
  config.correlation_id = -> { Current.request_id }   # e.g. Rails ActionDispatch::RequestId
end

result = ImportDataset.execute(dataset_id: 456)
result.xid                              #=> "abc-123-..."
result.chain.xid                        #=> "abc-123-..."
result.chain.map(&:xid).uniq            #=> ["abc-123-..."]
```

Details: [Configuration - Correlation ID](https://drexed.github.io/cmdx/configuration/#correlation-id-xid).

## Fiber Storage

The “current” chain lives on the current **Fiber** — so each thread’s default fiber (and each `Fiber.new`) gets its own chain. CMDx’s `Workflow` parallel bits copy the parent chain into worker threads on purpose so everything still rolls up under one trace; a mutex inside the chain keeps concurrent `push`es safe.

```ruby
# Thread A — its root fiber gets a fresh chain
Thread.new do
  result = ImportDataset.execute(file_path: "/data/batch1.csv")
  result.cid    #=> "018c2b95-b764-7615-a924-cc5b910ed1e5"
end

# Thread B — completely separate chain
Thread.new do
  result = ImportDataset.execute(file_path: "/data/batch2.csv")
  result.cid    #=> "018c2c11-c821-7892-b156-dd7c921fe2a3"
end

# Inspect or clear the current fiber's chain (rarely needed)
CMDx::Chain.current  #=> Returns current chain or nil
CMDx::Chain.clear    #=> Clears current fiber's chain (Runtime does this on teardown)
```

Warning

After the root task tears down, the chain is **frozen**. `CMDx::Chain.clear` is mostly for test setup. Try to mutate a frozen chain and Ruby will hand you a `FrozenError`.
