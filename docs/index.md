---
hide:
  - navigation
  - toc
---

<style>
.md-main__inner { max-width: none; }
.md-content__inner { padding: 0; }
.md-content__inner > :first-child { margin-top: 0; }

/* Hero section */
.hero {
  text-align: center;
  padding: 4rem 1rem 3rem;
  background: linear-gradient(135deg, rgba(254, 24, 23, 0.03) 0%, transparent 50%);
}
.hero .logo {
  margin-bottom: 2rem;
}
.hero h1 {
  font-size: 3rem;
  font-weight: 700;
  margin-bottom: 1.5rem;
  line-height: 1.2;
}
.hero h1 span {
  background: linear-gradient(135deg, #fe1817 0%, #d40000 100%);
  -webkit-background-clip: text;
  -webkit-text-fill-color: transparent;
  background-clip: text;
}
.hero .tagline {
  font-size: 1.35rem;
  color: var(--md-typeset-color);
  opacity: 0.85;
  max-width: 850px;
  margin: 0 auto 2rem;
  line-height: 1.6;
}
.hero .buttons {
  display: flex;
  gap: 1rem;
  justify-content: center;
  flex-wrap: wrap;
  margin-bottom: 3rem;
}
.hero .buttons a {
  padding: 0.8rem 2rem;
  border-radius: 8px;
  font-weight: 600;
  text-decoration: none;
  transition: transform 0.2s, box-shadow 0.2s;
}
.hero .buttons a:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 12px rgba(0,0,0,0.15);
}
.hero .buttons .primary {
  background: linear-gradient(135deg, #fe1817 0%, #d40000 100%);
  color: white !important;
}
.hero .buttons .secondary {
  background: var(--md-code-bg-color);
  color: var(--md-typeset-color) !important;
  border: 1px solid var(--md-default-fg-color--lightest);
}

/* Code showcase - Terminal style */
.code-showcase {
  max-width: 720px;
  margin: 0 auto;
  text-align: left;
  border-radius: 12px;
  overflow: hidden;
  box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.25);
}
.code-showcase .terminal-header {
  background: #2a2a2a;
  padding: 12px 16px;
  display: flex;
  align-items: center;
  gap: 8px;
}
.code-showcase .terminal-buttons {
  display: flex;
  gap: 8px;
}
.code-showcase .terminal-btn {
  width: 12px;
  height: 12px;
  border-radius: 50%;
}
.code-showcase .terminal-btn.close { background: #ff5f57; }
.code-showcase .terminal-btn.minimize { background: #febc2e; }
.code-showcase .terminal-btn.maximize { background: #28c840; }
.code-showcase .terminal-title {
  flex: 1;
  text-align: center;
  font-family: var(--md-code-font-family);
  font-size: 0.8rem;
  color: #999;
  margin-right: 52px;
}
.code-showcase pre {
  margin: 0 !important;
  border-radius: 0 !important;
}
.code-showcase .highlight {
  border-radius: 0 !important;
}
.code-showcase .highlighttable {
  border-radius: 0 !important;
}

/* Section styling */
.section {
  padding: 4rem 2rem;
  max-width: 1200px;
  margin: 0 auto;
}
.section-alt {
  background: var(--md-code-bg-color);
}
.section h2 {
  text-align: center;
  font-size: 2.2rem;
  margin-bottom: 0.75rem;
}
.section .subtitle {
  text-align: center;
  font-size: 1.1rem;
  color: var(--md-default-fg-color--light);
  margin-bottom: 3rem;
  max-width: 600px;
  margin-left: auto;
  margin-right: auto;
}

/* Feature grid */
.features {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(280px, 1fr));
  gap: 2rem;
}
.feature {
  padding: 1.75rem;
  border-radius: 12px;
  background: var(--md-default-bg-color);
  border: 1px solid var(--md-default-fg-color--lightest);
  transition: border-color 0.2s, box-shadow 0.2s;
}
.feature:hover {
  border-color: #fe1817;
  box-shadow: 0 4px 20px rgba(254, 24, 23, 0.1);
}
.feature h3 {
  font-size: 1.15rem;
  margin-bottom: 0.5rem;
  display: flex;
  align-items: center;
  gap: 0.5rem;
}
.feature h3::before {
  content: "";
  width: 8px;
  height: 8px;
  background: #fe1817;
  border-radius: 50%;
}
.feature p {
  color: var(--md-default-fg-color--light);
  margin: 0;
  line-height: 1.6;
}

/* Use cases */
.use-cases {
  display: grid;
  grid-template-columns: repeat(auto-fit, minmax(260px, 1fr));
  gap: 1.5rem;
}
.use-case {
  padding: 1.5rem;
  border-radius: 10px;
  background: var(--md-default-bg-color);
  border: 1px solid var(--md-default-fg-color--lightest);
}
.use-case h3 {
  font-size: 1.1rem;
  margin-bottom: 0.5rem;
}
.use-case p {
  color: var(--md-default-fg-color--light);
  margin: 0;
  font-size: 0.95rem;
}

/* Badges */
.badges {
  display: flex;
  gap: 0.5rem;
  justify-content: center;
  margin-bottom: 2rem;
}

/* Stats */
.stats {
  display: flex;
  justify-content: center;
  gap: 3rem;
  flex-wrap: wrap;
  margin-top: 2rem;
  padding-top: 2rem;
  border-top: 1px solid var(--md-default-fg-color--lightest);
}
.stat {
  text-align: center;
}
.stat .number {
  font-size: 2rem;
  font-weight: 700;
  color: #fe1817;
}
.stat .label {
  font-size: 0.9rem;
  color: var(--md-default-fg-color--light);
}

/* Quick start code block */
.section .highlight {
  max-width: 480px;
  margin-left: auto;
  margin-right: auto;
}
</style>

<!-- Hero Section -->
<div class="hero">
  <div class="logo">
    <img src="assets/cmdx-light-logo.png" alt="CMDx" class="only-light" />
    <img src="assets/cmdx-dark-logo.png" alt="CMDx" class="only-dark" />
  </div>

  <div class="badges">
    <a href="https://rubygems.org/gems/cmdx"><img alt="Version" src="https://img.shields.io/gem/v/cmdx"></a>
    <a href="https://github.com/drexed/cmdx/actions/workflows/ci.yml"><img alt="Build" src="https://github.com/drexed/cmdx/actions/workflows/ci.yml/badge.svg"></a>
    <a href="https://github.com/drexed/cmdx/blob/main/LICENSE.txt"><img alt="License" src="https://img.shields.io/badge/license-LGPL%20v3-blue.svg"></a>
  </div>

  <h1>
    Build <span>powerful</span>, <span>predictable</span>,<br>
    and <span>maintainable</span> business logic
  </h1>

  <p class="tagline">
    CMDx is a Ruby framework for clean, composable business logic—designed to replace service-object sprawl.
  </p>

  <div class="buttons">
    <a href="getting_started/" class="primary">Get Started</a>
    <a href="https://github.com/drexed/cmdx" class="secondary">View on GitHub</a>
  </div>

  <div class="code-showcase">
    <div class="terminal-header">
      <div class="terminal-buttons">
        <span class="terminal-btn close"></span>
        <span class="terminal-btn minimize"></span>
        <span class="terminal-btn maximize"></span>
      </div>
      <span class="terminal-title">app/tasks/approve_loan.rb</span>
    </div>

```ruby
class ApproveLoan < CMDx::Task
  on_success :notify_applicant!

  required :application_id, type: :integer
  optional :override_checks, default: false

  def work
    if application.nil?
      fail!("Application not found", code: 404)
    elsif application.approved?
      skip!("Application already approved")
    else
      context.approval = application.approve!
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

  </div>
</div>

<!-- Why CMDx Section -->
<div class="section-alt">
  <div class="section">
    <h2>Why Choose CMDx?</h2>
    <p class="subtitle">Everything you need to build reliable, testable business logic in Ruby</p>

    <div class="features">
      <div class="feature">
        <h3>Zero Dependencies</h3>
        <p>Pure Ruby with no external dependencies. Works with any Ruby project—Rails, Sinatra, or plain Ruby scripts.</p>
      </div>
      <div class="feature">
        <h3>Type-Safe Attributes</h3>
        <p>Declare inputs with automatic type coercion, validation, and defaults. Catch errors before they cause problems.</p>
      </div>
      <div class="feature">
        <h3>Built-in Observability</h3>
        <p>Structured logging with chain IDs, runtime metrics, and execution tracing. Debug complex workflows with ease.</p>
      </div>
      <div class="feature">
        <h3>Composable Workflows</h3>
        <p>Chain tasks together into sequential pipelines. Build complex processes from simple, tested building blocks.</p>
      </div>
      <div class="feature">
        <h3>Predictable Results</h3>
        <p>Every execution returns a result object with clear success, failure, or skipped states. No more exception juggling.</p>
      </div>
      <div class="feature">
        <h3>Production Ready</h3>
        <p>Automatic retries, middleware support, callbacks, and internationalization. Battle-tested in real applications.</p>
      </div>
    </div>
  </div>
</div>

<!-- Use Cases Section -->
<div class="section">
  <h2>Designed For</h2>
  <p class="subtitle">CMDx shines wherever you need structured, reliable business logic</p>

  <div class="use-cases">
    <div class="use-case">
      <h3>🏦 Financial Operations</h3>
      <p>Payment processing, loan approvals, and transaction handling with full audit trails</p>
    </div>
    <div class="use-case">
      <h3>📧 Notification Systems</h3>
      <p>Multi-channel notifications with fallbacks, personalization, and delivery tracking</p>
    </div>
    <div class="use-case">
      <h3>🔄 Data Pipelines</h3>
      <p>ETL processes, data migrations, and transformations with checkpoints and recovery</p>
    </div>
    <div class="use-case">
      <h3>🛒 E-commerce Flows</h3>
      <p>Order processing, inventory management, and fulfillment orchestration</p>
    </div>
    <div class="use-case">
      <h3>👤 User Onboarding</h3>
      <p>Registration flows, verification steps, and welcome sequences</p>
    </div>
    <div class="use-case">
      <h3>🤖 Background Jobs</h3>
      <p>Complex async operations with Sidekiq, retry logic, and error handling</p>
    </div>
  </div>
</div>

<!-- Quick Start Section -->
<div class="section-alt">
  <div class="section">
    <h2>Get Started in Seconds</h2>
    <p class="subtitle">Add CMDx to your project and start building</p>

```bash
gem install cmdx
# or
bundle add cmdx
```

    <div style="text-align: center; margin-top: 2rem;">
      <a href="getting_started/" class="md-button md-button--primary" style="margin-right: 0.5rem;">Read the Docs</a>
      <a href="https://github.com/drexed/cmdx" class="md-button">Star on GitHub</a>
    </div>
  </div>
</div>
