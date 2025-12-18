# Flipper Feature Flags

Control task execution based on Flipper feature flags.

<https://github.com/flippercloud/flipper>

### Setup

```ruby
# lib/cmdx_flipper_middleware.rb
class CmdxFlipperMiddleware
  def self.call(task, **options, &)
    feature_name = options.fetch(:feature)
    actor = options.fetch(:actor, -> { task.context[:user] })

    # Resolve actor if it's a proc
    actor = actor.call if actor.respond_to?(:call)

    if Flipper.enabled?(feature_name, actor)
      yield
    else
      # Option 1: Skip the task
      task.skip!("Feature #{feature_name} is disabled")

      # Option 2: Fail the task
      # task.fail!("Feature #{feature_name} is disabled")
    end
  end
end
```

### Usage

```ruby
class NewFeatureTask < CMDx::Task
  # Execute only if :new_feature is enabled for the user in context
  register :middleware, CmdxFlipperMiddleware,
    feature: :new_feature

  # Customize the actor resolution
  register :middleware, CmdxFlipperMiddleware,
    feature: :beta_access,
    actor: -> { task.context[:company] }

  def work
    # ...
  end
end
```

