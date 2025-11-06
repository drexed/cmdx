# API Reference

This section contains the complete API reference documentation for CMDx, generated from YARD documentation.

## Main Module

- [CMDx](CMDx.md) - Main module and entry point

## Core Classes

- [CMDx::Task](CMDx/Task.md) - Base class for all tasks
- [CMDx::Workflow](CMDx/Workflow.md) - Workflow composition module
- [CMDx::Result](CMDx/Result.md) - Execution result object
- [CMDx::Context](CMDx/Context.md) - Context object for data sharing
- [CMDx::Chain](CMDx/Chain.md) - Execution chain tracking
- [CMDx::Executor](CMDx/Executor.md) - Task executor
- [CMDx::Pipeline](CMDx/Pipeline.md) - Workflow pipeline executor

## Configuration

- [CMDx::Configuration](CMDx/Configuration.md) - Global configuration

## Attributes

- [CMDx::Attribute](CMDx/Attribute.md) - Attribute definition
- [CMDx::AttributeValue](CMDx/AttributeValue.md) - Attribute value handling
- [CMDx::AttributeRegistry](CMDx/AttributeRegistry.md) - Attribute registry

## Coercions

- [CMDx::Coercions](CMDx/Coercions.md) - Coercion module
- [CMDx::CoercionRegistry](CMDx/CoercionRegistry.md) - Coercion registry

See individual coercion classes in [CMDx::Coercions](CMDx/Coercions/) for specific type conversions.

## Validators

- [CMDx::Validators](CMDx/Validators.md) - Validator module
- [CMDx::ValidatorRegistry](CMDx/ValidatorRegistry.md) - Validator registry

See individual validator classes in [CMDx::Validators](CMDx/Validators/) for specific validation rules.

## Middlewares

- [CMDx::Middlewares](CMDx/Middlewares.md) - Middleware module
- [CMDx::MiddlewareRegistry](CMDx/MiddlewareRegistry.md) - Middleware registry

See individual middleware classes in [CMDx::Middlewares](CMDx/Middlewares/) for specific middleware implementations.

## Callbacks

- [CMDx::CallbackRegistry](CMDx/CallbackRegistry.md) - Callback registry

## Logging

- [CMDx::LogFormatters](CMDx/LogFormatters.md) - Log formatter module

See individual formatter classes in [CMDx::LogFormatters](CMDx/LogFormatters/) for specific log formats.

## Utilities

- [CMDx::Utils](CMDx/Utils.md) - Utility module
- [CMDx::Locale](CMDx/Locale.md) - Internationalization support
- [CMDx::Identifier](CMDx/Identifier.md) - ID generation
- [CMDx::Deprecator](CMDx/Deprecator.md) - Deprecation handling

## Errors and Faults

- [CMDx::Errors](CMDx/Errors.md) - Error collection
- [CMDx::Fault](CMDx/Fault.md) - Base fault class

