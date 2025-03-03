# Example

The following is a full example of task that is commonly implemented.

## Setup

```ruby
class ProcessOrderTask < CMDx::Task

  required :order
  required :billing_details, :shipping_details, from: :order

  optional :package do
    required :delivery_company, default: -> { Current.account.premium? ? "UPS" : "DHL" }
    optional :weight, :volume, type: :float
  end

  after_execution :track_metrics

  def call
    if cart_abandoned?
      skip!(reason: "Cart was abandoned due to 30 days of inactivity")
    elsif cart_items_out_of_stock?
      fail!(reason: "Items in the cart are out of stock", item: [123, 987])
    else
      charge_payment_method
      ship_order_packages
      send_confirmation_email
    end
  end

  private

  def charge_payment_method
    @charge_payment_method ||= ChargePaymentMethodTask.call(details: billing_details)
  end

  def ship_order_packages
    @ship_order_packages ||= ShipOrderPackagesTask.call(details: shipping_details)
  end

  def send_confirmation_email
    return if charge_payment_method.failed? || ship_order_packages.bad?

    BatchSendConfirmationNotifications.call(context)
  end

  def track_metrics
    if Rails.env.development?
      logger.debug { "Sending metrics to collector" }
    else
      TrackMetricsTask.call(metric: :process_order, status: order.status)
    end
  end

end
```

## Execution

```ruby
class OrdersController < ApplicationController

  def create
    task = ProcessOrderTask.call(order_params)

    if task.success?
      flash[:success] = "Order is on its way!"
      redirect_to(my_orders_path)
    else
      flash[:error] = "Whoops something is wrong: #{task.metadata[:reason]}"
      render(:new)
    end
  end

end
```

---

- **Prev:** [Tips & Tricks](https://github.com/drexed/cmdx/blob/main/docs/tips_and_tricks.md)
- **Next:** [Getting Started](https://github.com/drexed/cmdx/blob/main/docs/getting_started.md)
