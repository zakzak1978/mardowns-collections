# The Expert Programmer's Prompt Bible
*v2.0 | Optimized for Architecture, Security, and Complexity*

## I. The Core Philosophy
Treat the LLM not as a search engine, but as a **Junior Staff Engineer** who is brilliant but lacks context.

**The "P.C.R.O." Framework:**
1.  **P**ersona: "Act as a [Role]..."
2.  **C**ontext: "The stack is [X], constraints are [Y]..."
3.  **R**equirements: "Maximize [Metric], strict typing, handle [Edge Case]..."
4.  **O**utput: "Output as [Format]..."

**The Golden Clause (Chain of Thought):**
> *ALWAYS append this to complex requests:*
> "Before generating code, plan your approach in pseudocode steps. Critique that plan for potential bottlenecks or security flaws, then execute the final code."

---

## II. Architecture & Design Prompts

### 1. The "System Architect" (New Features)
*Use for: High-level design, trade-off analysis.*
> **Role:** Principal Software Architect.
> **Task:** Design a [System/Component] to handle [Scale/Requirements].
> **Constraints:**
> * **Scalability:** Must handle [X] requests/sec.
> * **Reliability:** Design for eventual consistency (or strict ACID if needed).
> **Output:**
> 1.  **Pattern Selection:** Recommend 2 design patterns (e.g., CQRS, Saga) and justify the choice.
> 2.  **Trade-off Matrix:** Compare your choice against the standard alternative regarding Complexity vs. Performance.
> 3.  **Failure Analysis:** Identify the single most likely point of failure in this design.
> 4.  **Interface Definition:** Define the core API schema / Interfaces.

### 2. The "Devil's Advocate" (Design Review)
*Use for: Validating your own ideas.*
> **Role:** A skeptical Senior Principal Engineer.
> **Input:** [Paste your design/code idea].
> **Task:** "Roast" this design.
> 1.  Where will this break under high load?
> 2.  What security vulnerability (OWASP) does this introduce?
> 3.  Why is this harder to maintain than a simpler alternative?
> 4.  **Score:** Rate the solution 1-10 on Maintainability.

---

## III. Implementation Prompts

### 3. The "Strict Implementer" (Production Code)
*Use for: Generating copy-paste ready code.*
> **Role:** Senior Backend Engineer specializing in [Language].
> **Task:** Implement [Functionality].
> **Hard Constraints:**
> * **Zero Dependencies:** Use standard library only (unless specified).
> * **Performance:** $O(n)$ complexity or better. Explain the Big-O.
> * **Safety:** Handle all edge cases (nulls, empty lists, boundary values).
> **Process:**
> 1.  Write the implementation plan.
> 2.  Write the code.
> 3.  Add JSDoc/Docstrings explaining *why* specific logic was chosen.

### 4. The "Modernizer" (Refactoring)
*Use for: Cleaning up legacy or "smelly" code.*
> **Role:** "Clean Code" Advocate.
> **Task:** Refactor the provided code.
> **Goals:**
> * Decouple logic (SOLID principles).
> * Improve readability without changing external behavior.
> * Add strict typing (if applicable).
> **Output:**
> * The refactored code.
> * A bulleted list of "Smells Removed."

---

## IV. Debugging & Security

### 5. The "Socratic Debugger"
*Use for: Deep, confusing bugs where the error is unclear.*
> **Role:** Low-level Systems Expert.
> **Problem:** I have a bug in [Component] exhibiting [Behavior].
> **Instructions:**
> * **Do NOT fix it yet.**
> * Ask me 3 clarifying questions about the environment/state to narrow down the root cause.
> * Once answered, propose 2 distinct hypotheses (e.g., Race Condition vs. Memory Leak).
> * Provide a script/strategy to isolate the variable and prove the hypothesis.

### 6. The "Security Auditor"
*Use for: Pre-commit checks.*
> **Role:** Red Team Security Researcher.
> **Task:** Audit the following code block for vulnerabilities.
> **Checklist:**
> * Injection (SQL, NoSQL, Command).
> * Insecure Deserialization.
> * Race Conditions.
> * Information Leakage (logging secrets).
> **Output:** A severity-ranked list of findings and the fixed code.

---

## V. Testing & Documentation

### 7. The "Edge Case Hunter" (Unit Tests)
*Use for: Reaching 100% coverage.*
> **Role:** QA Automation Engineer.
> **Task:** Write a test suite for [Function/Component] using [Framework].
> **Requirements:**
> * **Happy Path:** 1 standard test.
> * **The Nasty Stuff:** Generate 5 malicious/edge-case inputs (e.g., Unicode overflow, negative integers, deeply nested JSON) and write tests for them.
> * **Mocking:** Mock all I/O.

### 8. The "Doc-Stringer"
*Use for: Generating maintainable docs.*
> **Role:** Technical Writer.
> **Task:** Document the code below.
> **Style:**
> * **Summary:** One sentence explaining what it does.
> * **Params:** Type and Constraints (e.g., "Must be > 0").
> * **Warning:** Add a "Warning" block for any non-obvious side effects or performance pitfalls.

---

## VI. Quick-Copy Snippets (The "Meta" Layer)

*Paste these at the end of your prompt to upgrade the output:*

* **For Accuracy:** "If you are 90% sure, say you are 90% sure. Do not hallucinate APIs. If the library doesn't exist, tell me."
* **For Brevity:** "No preamble. No 'Here is the code'. Just the code block."
* **For Learning:** "After the code, explain the specific architectural trade-off you made between Memory and CPU cycles."

## VII. Real-World Example Library
*Copy-paste these scenarios and fill in your specific details.*

### Example A: The "System Architect" (High-Level Design)
**Scenario:** You need to build a rate-limiting service for your API.

> **Role:** Principal Backend Architect.
>
> **Context:** We are building a distributed Rate Limiter for a high-traffic API Gateway (100k requests/sec). We are using Redis for state.
>
> **Task:** Design the logic for this limiter.
>
> **Requirements:**
> 1.  **Algorithm:** Compare "Token Bucket" vs. "Fixed Window" vs. "Sliding Window Log". Recommend the best one for strict accuracy vs. performance trade-offs.
> 2.  **Concurrency:** Explain how you will handle race conditions when two requests hit the instance simultaneously.
> 3.  **Latency:** The check must add no more than 10ms to the request time.
>
> **Output:**
> * A sequence diagram description.
> * Pseudocode for the core `allow_request(user_id)` function.
> * A "Failure Mode Analysis" (what happens if Redis goes down?).

---

### Example B: The "Strict Implementer" (.NET/C# Focus)
**Scenario:** You need a robust background service to process stock market data (based on your interest in Screener.in/stocks).

> **Role:** Senior .NET Core Developer.
>
> **Task:** Implement a `BackgroundService` in C# that polls an external API for stock prices every 1 minute.
>
> **Hard Constraints:**
> 1.  **Resilience:** Implement a "Circuit Breaker" pattern. If the API fails 5 times, back off for 5 minutes.
> 2.  **Concurrency:** Use `SemaphoreSlim` to ensure we never process more than 5 tickers concurrently.
> 3.  **Cancellation:** Strictly respect the `CancellationToken`. If the app shuts down, the service must stop gracefully within 2 seconds.
>
> **Process:**
> 1.  Outline the `ExecuteAsync` logic loop.
> 2.  Write the code using standard `Microsoft.Extensions.Hosting`.
> 3.  Add comments explaining memory management for the `HttpClient`.

---

### Example C: The "Modernizer" (Refactoring Logic)
**Scenario:** You have a messy legacy function that calculates tax but is full of nested `if/else` statements.

> **Role:** Clean Code Specialist.
>
> **Task:** Refactor the `calculate_order_tax` function provided below.
>
> **Critique & Fix:**
> 1.  **Cyclomatic Complexity:** The current code has a complexity score of 15. Reduce this to under 5.
> 2.  **Pattern:** Replace the nested `if/else` blocks with a "Strategy Pattern" or a lookup dictionary.
> 3.  **Typing:** Convert this from loose types to strict types (e.g., creating a `TaxRules` interface).
>
> **Code:**
> ```javascript
> // [PASTE MESSY CODE HERE]
> ```

---

### Example D: The "Socratic Debugger" (The Mystery Bug)
**Scenario:** Your application runs fine for 2 hours, then memory spikes and it crashes.

> **Role:** JVM/CLR Internals Expert.
>
> **Problem:** My worker service crashes with an `OutOfMemoryException` after exactly 2 hours of processing large CSV files.
>
> **Instruction:**
> * **Do NOT tell me to "check for memory leaks."** That is too generic.
> * **Ask:** Ask me 3 questions about how I am handling the `FileStream` and object disposal.
> * **Hypothesize:** Based on the fact that it happens at a specific time interval, propose a theory involving the Garbage Collector (GC) generations (Gen 0 vs Gen 2).
> * **Tooling:** Tell me exactly which counter to look at in my profiler.