# Working on Tasks as an AI Agent

This document outlines the process for an AI agent to contribute to this project by working on the tasks listed in `TODO.md`.

## Workflow

The recommended workflow is designed to be collaborative and iterative, ensuring that the agent's contributions align with the project's goals.

1.  **Task Selection:** I will start by picking a task from the `TODO.md` file. If the user has a specific task in mind, they can instruct me to work on that.

2.  **Clarification and Breakdown:** Before writing any code, I will analyze the selected task and break it down into smaller, manageable steps. I will then present this breakdown to you and ask for any clarifications or confirmations. This is a crucial step to ensure we are on the same page.

3.  **Implementation:** Once the plan is approved, I will start implementing the changes. I will work on one sub-task at a time.

4.  **Code Style and Conventions:** I will adhere to the existing code style and conventions of the project. I will analyze the surrounding code to understand the patterns and apply them to the new code.

5.  **Verification:** After implementing a piece of functionality, I will look for existing tests to verify my changes. If there are no tests, I will ask if you want me to write some.

6.  **Iteration and Feedback:** Throughout the process, I will keep you informed of my progress. I encourage you to provide feedback at any stage.

## Example Interaction

Here's an example of how we can work together on a task from `TODO.md`:

**You:** "Let's work on the 'Challenge view' task. Start with adding a 'show' view for the audience."

**Me:** "Okay, I will start with the 'show' view. Here's my plan:
1.  Create a new screen file `show_screen.dart`.
2.  This screen will display the current challenge and the remaining time.
3.  I will need a data model for `Challenge`. Based on the task, it should have at least a `name` and a `duration`. Does that sound right?
4.  I will add a route for this new screen in `main.dart`.

Does this plan look good to you?"

**You:** "Yes, that sounds good. Let's proceed."

This collaborative approach ensures that the development process is transparent and the final result meets your expectations.

# Tooling
We should use the mcp servers for git and dart.