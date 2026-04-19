---
hide:
  - navigation
  - toc
title: Home
template: home.html
---

```ruby
class ApproveLoan < CMDx::Task
  register :middleware, DeeplI18nMiddleware

  required :application_id, coerce: :integer

  optional :override_checks, default: false

  on_success :notify_applicant!

  output :approved_at, presence: true

  def work
    if application.nil?
      fail!("Application not found", code: 404)
    elsif application.approved?
      skip!("Application already approved")
    else
      application.approve!
      context.approved_at = Time.current
    end
  end

  private

  def application
    @application ||= LoanApplication.find_by(id: application_id)
  end

  def notify_applicant!
    ApprovalMailer.approved(application).deliver_later
  end
end
```
