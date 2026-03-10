---
date: 2026-06-03
authors:
  - drexed
categories:
  - Tutorials
slug: real-world-cmdx-multi-tenant-saas
---

# Real-World CMDx: Multi-Tenant SaaS Patterns

*Part 4 of the Real-World CMDx series*

Multi-tenancy changes everything. That simple `Users::Register` task you wrote? Now it needs to know which tenant it's operating on. Your database queries need scoping. Your logging needs tenant context. Your middleware stack needs to enforce tenant isolation. And if you get any of it wrong, Customer A sees Customer B's data, and you're writing an incident report instead of features.

I've built three multi-tenant SaaS products with Ruby and CMDx. Each one taught me something about where tenant boundaries belong and, more importantly, where they don't. The pattern I've settled on keeps tenant concerns out of business logic entirely — tasks don't know they're multi-tenant. The middleware and base classes handle it.

<!-- more -->

## The Tenant Context Problem

In a typical multi-tenant Rails app, tenant scoping is everywhere:

```ruby
class OrderService
  def create(user, items)
    # Who sets Current.tenant? The controller? A middleware?
    # What if this runs in a background job?
    Order.where(tenant: Current.tenant).create!(user: user, items: items)
    InventoryService.new(Current.tenant).reserve(items)
    NotificationService.notify(Current.tenant, user, :order_created)
  end
end
```

`Current.tenant` is a global, mutable, thread-local variable. It works until it doesn't — until a background job runs without setting it, or a before_action forgets to set it, or two requests race on the same thread in a non-threadsafe scenario.

With CMDx, the tenant flows through the context — explicit, immutable, and traceable.

## Tenant-Aware Base Task

Start with a base task that enforces tenant presence:

```ruby
class TenantTask < ApplicationTask
  required :tenant

  before_execution :set_tenant_scope

  private

  def set_tenant_scope
    ActsAsTenant.current_tenant = tenant
  end
end
```

Every task that touches tenant-scoped data inherits from `TenantTask`. The tenant is a required attribute — not a global, not a thread-local, not an implicit assumption. If you forget to pass it, the task fails at validation before any code runs.

`ActsAsTenant` (or whatever scoping library you use) gets set in a callback, keeping it out of the business logic.

## Tenant Middleware for Isolation

For defense-in-depth, add middleware that ensures tenant scoping is active:

```ruby
class TenantIsolation
  def call(task, options)
    tenant = task.context[:tenant]

    unless tenant
      task.result.tap { |r| r.fail!("Tenant context missing", code: :tenant_required) }
      return
    end

    ActsAsTenant.with_tenant(tenant) do
      yield
    end
  end
end
```

Register it globally for extra safety:

```ruby
CMDx.configure do |config|
  config.middlewares.register TenantIsolation
end
```

The middleware uses `with_tenant` which scopes all ActiveRecord queries within the block and restores the previous tenant when the block exits. This is safer than setting `current_tenant` directly — if the task raises, the tenant scope is still restored.

### Why Both Callback and Middleware?

The `before_execution` callback sets the tenant for the task's `work` method. The middleware scopes the entire execution, including callbacks and nested tasks. Belt and suspenders — one can't run without the other, and both are harmless if duplicated.

## Tenant-Scoped Logging

Add the tenant to every log entry via a middleware that injects tenant context into metadata:

```ruby
class TenantLogging
  def call(task, options)
    tenant = task.context[:tenant]

    yield.tap do |result|
      result.metadata[:tenant_slug] = tenant.slug if tenant
    end
  end
end

class TenantTask < ApplicationTask
  required :tenant

  register :middleware, TenantLogging
  before_execution :set_tenant_scope

  private

  def set_tenant_scope
    ActsAsTenant.current_tenant = tenant
  end
end
```

Now every log entry includes the tenant:

```json
{"chain_id":"abc123","class":"Orders::Create","status":"success","metadata":{"tenant_slug":"acme","runtime":34}}
```

Filter your log aggregator by `metadata.tenant_slug:"acme"` and see all task executions for that tenant. Cross-reference with `chain_id` to trace a single request.

## Per-Tenant Configuration

Different tenants have different needs. Enterprise tenants might need longer timeouts, different retry policies, or additional middleware:

```ruby
class TenantConfigMiddleware
  def call(task, options)
    tenant = task.context[:tenant]
    return yield unless tenant

    if tenant.feature?(:enhanced_logging)
      task.logger.level = :debug
    end

    yield
  end
end
```

For tasks that behave differently per tenant:

```ruby
class Reports::Generate < TenantTask
  required :report_type, inclusion: { in: %w[summary detailed] }

  returns :report

  def work
    context.report = case report_type
                     when "detailed"
                       fail!("Detailed reports require Enterprise plan",
                         code: :plan_required) unless tenant.enterprise?
                       DetailedReportBuilder.new(tenant).build
                     when "summary"
                       SummaryReportBuilder.new(tenant).build
                     end
  end
end
```

Feature gating happens inside the task with `fail!`. The caller gets a structured error they can display to the user.

## Tenant-Scoped Workflows

Workflows compose tenant-scoped tasks naturally:

```ruby
class Onboarding::SetupTenant < CMDx::Task
  include CMDx::Workflow

  settings(
    workflow_breakpoints: ["failed"],
    tags: ["onboarding", "tenant-setup"]
  )

  task Tenants::Create
  task Tenants::ProvisionDatabase, if: :dedicated_database?
  task Tenants::SeedDefaultData
  task Tenants::CreateAdminUser
  task Tenants::ConfigureBilling
  task Tenants::SendWelcome

  private

  def dedicated_database?
    context.plan == "enterprise"
  end
end
```

### Create the Tenant

```ruby
class Tenants::Create < ApplicationTask
  required :name, presence: true, length: { min: 2, max: 100 }
  required :slug, format: /\A[a-z0-9-]+\z/, length: { min: 2, max: 50 }
  required :plan, inclusion: { in: %w[starter growth enterprise] }
  required :owner_email, format: { with: URI::MailTo::EMAIL_REGEXP }

  returns :tenant

  def work
    fail!("Slug already taken", code: :slug_taken) if Tenant.exists?(slug: slug)

    context.tenant = Tenant.create!(
      name: name,
      slug: slug,
      plan: plan,
      status: :provisioning
    )
  end
end
```

### Seed Default Data

```ruby
class Tenants::SeedDefaultData < TenantTask
  returns :seed_summary

  def work
    roles = Role.insert_all([
      { name: "admin", tenant_id: tenant.id },
      { name: "member", tenant_id: tenant.id },
      { name: "viewer", tenant_id: tenant.id }
    ])

    categories = Category.insert_all(
      default_categories.map { |c| c.merge(tenant_id: tenant.id) }
    )

    context.seed_summary = {
      roles: roles.count,
      categories: categories.count
    }

    logger.info "Seeded #{roles.count} roles and #{categories.count} categories"
  end

  private

  def default_categories
    [
      { name: "General", color: "#6366f1" },
      { name: "Billing", color: "#22c55e" },
      { name: "Support", color: "#f59e0b" }
    ]
  end
end
```

### Create the Admin User

```ruby
class Tenants::CreateAdminUser < TenantTask
  required :owner_email

  returns :admin_user

  def work
    context.admin_user = User.create!(
      email: owner_email,
      tenant: tenant,
      role: Role.find_by!(tenant: tenant, name: "admin"),
      status: :pending_verification
    )
  end
end
```

Every task after `Tenants::Create` inherits from `TenantTask`, so they all have the `tenant` attribute required and the scoping middleware active. The tenant flows through context automatically — `Tenants::Create` sets `context.tenant`, and every subsequent task reads it as a required attribute.

## Cross-Tenant Operations

Admin tasks that operate across tenants need to bypass the tenant scope:

```ruby
class Admin::BaseTask < ApplicationTask
  deregister :middleware, TenantIsolation
end

class Admin::GenerateUsageReport < Admin::BaseTask
  required :billing_period, type: :date

  settings(tags: ["admin", "billing"])

  returns :report

  def work
    context.report = Tenant.active.map do |tenant|
      {
        tenant_id: tenant.id,
        tenant_name: tenant.name,
        plan: tenant.plan,
        active_users: tenant.users.active.count,
        storage_mb: tenant.storage_used_mb,
        api_calls: tenant.api_calls_for(billing_period)
      }
    end
  end
end
```

By deregistering `TenantIsolation`, admin tasks can query across all tenants. This is explicit and auditable — you can grep your codebase for `Admin::BaseTask` to find every cross-tenant operation.

## Tenant-Aware Background Jobs

Combine the patterns from [Part 3](real-world-cmdx-background-jobs.md) with tenant scoping:

```ruby
class TenantJob
  include Sidekiq::Job

  def perform(args)
    tenant = Tenant.find(args["tenant_id"])

    CMDx::Middlewares::Correlate.use(args["correlation_id"]) do
      ActsAsTenant.with_tenant(tenant) do
        task_class = args["task_class"].constantize
        task_class.execute!(args["context"].merge("tenant" => tenant))
      end
    end
  end
end
```

Enqueue with tenant context:

```ruby
class Billing::EnqueueInvoiceGeneration < TenantTask
  def work
    correlation_id = CMDx::Middlewares::Correlate.id

    TenantJob.perform_async(
      "tenant_id" => tenant.id,
      "correlation_id" => correlation_id,
      "task_class" => "Billing::GenerateInvoice",
      "context" => { "billing_period" => Date.today.to_s }
    )

    logger.info "Enqueued invoice generation for tenant #{tenant.slug}"
  end
end
```

The tenant ID is serialized with the job. When it executes, the tenant scope is restored before the task runs. The `correlation_id` bridges the async boundary for tracing.

## Testing Multi-Tenant Tasks

Test with explicit tenant context:

```ruby
RSpec.describe Orders::Create do
  let(:tenant) { create(:tenant) }
  let(:user) { create(:user, tenant: tenant) }

  before do
    CMDx.reset_configuration!
    CMDx::Chain.clear
  end

  it "creates an order scoped to the tenant" do
    result = Orders::Create.execute(
      tenant: tenant,
      user: user,
      items: [{ product_id: 1, quantity: 2 }]
    )

    expect(result).to be_success
    expect(result.context.order.tenant).to eq(tenant)
  end

  it "fails without a tenant" do
    result = Orders::Create.execute(
      user: user,
      items: [{ product_id: 1, quantity: 2 }]
    )

    expect(result).to be_failed
    expect(result.metadata[:errors][:messages]).to have_key(:tenant)
  end
end
```

For tenant isolation integration tests:

```ruby
RSpec.describe "tenant isolation" do
  let(:tenant_a) { create(:tenant) }
  let(:tenant_b) { create(:tenant) }

  it "does not leak data between tenants" do
    Orders::Create.execute(
      tenant: tenant_a,
      user: create(:user, tenant: tenant_a),
      items: [{ product_id: 1, quantity: 1 }]
    )

    result = Orders::List.execute(tenant: tenant_b)

    expect(result).to be_success
    expect(result.context.orders).to be_empty
  end
end
```

The tenant is always explicit. No test setup that silently sets `Current.tenant`. No test pollution across examples.

## The Architecture at a Glance

```
CMDx.configure
  └── TenantIsolation middleware (global)
  └── ErrorTracking middleware (global)

ApplicationTask < CMDx::Task
  └── DatabaseTransaction middleware

TenantTask < ApplicationTask
  └── required :tenant
  └── TenantLogging middleware
  └── before_execution :set_tenant_scope

Admin::BaseTask < ApplicationTask
  └── deregister TenantIsolation (cross-tenant access)

Domain Tasks (Orders::Create, Billing::Charge, etc.)
  └── inherit from TenantTask
  └── business logic only — no tenant plumbing
```

The business logic layer doesn't know about multi-tenancy. `Orders::Create` creates an order. `Billing::Charge` charges a card. The tenant scoping, isolation, logging, and gating all happen in the layers below.

That's the whole point: tenant boundaries are an infrastructure concern, not a business logic concern. CMDx's layered architecture — middleware, base classes, callbacks — gives you the right places to put infrastructure without polluting the code that matters.

Happy coding!

## References

- [Middlewares](https://drexed.github.io/cmdx/middlewares/)
- [Callbacks](https://drexed.github.io/cmdx/callbacks/)
- [Configuration](https://drexed.github.io/cmdx/configuration/)
- [Tips and Tricks](https://drexed.github.io/cmdx/tips_and_tricks/)
