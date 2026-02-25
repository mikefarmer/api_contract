# Contributing to ApiContract

Thank you for your interest in contributing! This guide will help you get started.

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/YOUR_USERNAME/api_contract.git
   cd api_contract
   ```
3. Install dependencies:
   ```bash
   bundle install
   ```
4. Make sure the test suite passes:
   ```bash
   bundle exec rspec
   bundle exec rubocop
   ```

## Making Changes

1. Create a feature branch from `main`:
   ```bash
   git checkout -b feature/my-change
   ```
2. Make your changes
3. Add or update tests for your changes
4. Ensure all tests pass and RuboCop is clean:
   ```bash
   bundle exec rspec
   bundle exec rubocop -a
   ```
5. Commit your changes with a clear message

## Submitting a Pull Request

1. Push your branch to your fork
2. Open a pull request against `main`
3. Describe the change and link any related issues
4. Wait for CI to pass and a maintainer to review

## Code Standards

- **Ruby 3.4+** required
- **RuboCop** — all code must pass with zero offenses
- **RSpec** — all public methods must have test coverage
- **YARD** — all public methods and classes must be documented

## Reporting Issues

Open an issue on GitHub with:
- A clear title and description
- Steps to reproduce (if applicable)
- Expected vs. actual behavior
- Ruby and Rails versions
