# Things that need to be done

## Description

This document outlines the high-level tasks for the project. It is intended for all contributors, including developers and AI agents.

### Task Granularity

Each item on the list represents a significant feature or piece of functionality. The goal is to provide a clear overview of what needs to be done without dictating the specific implementation details. This allows for flexibility and creativity during development.

### Data Structures

While some tasks may imply certain data entities (e.g., a `Challenge`), the specific structure of these entities is intentionally left open. Define them as needed during implementation, focusing on the essential properties required to fulfill the task's requirements.

If any questions arise regarding implementation or data structures, please ask the maintainers.

### Working with AI Agents

When working with an AI agent, the ideal workflow is collaborative. The agent should break down high-level tasks into smaller, manageable steps. Before implementing each step, the agent should ask clarifying questions to ensure the approach aligns with the project's goals. This iterative process of questioning and clarification helps to ensure that the final implementation is well-aligned with the project's vision.

---

- [ ] Challenge view
  - [x] Add a "show" view for the audience, displaying only the current challenge and remaining time.
  - [x] Create a flashy countdown overlay
    - [x] When waiting for a challenge to start.
    - [x] For the last 10 seconds of an active challenge.
    - [x] The countdown should feature large, animated numbers to engage the audience.
  - [x] Display challenger's name in the app bar.
    - [x] Allow challenger to set their name when starting a challenge.
  - [x] When the timer expires.
    - [x] Block user's screen with a waiting message
    - [x] Shake the screen to indicate the end of the challenge.
  - [ ] Shake the screen when the challenger is "on fire".
    - [ ] Define the "on fire" state (e.g., based on typing speed).

- [ ] Admin view
  - [x] Display a list of challengers with their name and status (e.g., "in progress," "finished," "blocked").
    - [x] Show both in 'Current challenge view' and 'Select challenge view'.
  - [x] Provide a button next to each challenger to block and unblock their screen.
  - [x] Clear a challenger manually.
  - [x] Add a button for the admin to clear all challengers manually.
  - [x] Automatically clear challengers only when the current challenge is stopped.
  - [x] Allow admin to change the remaining time of the challenge.