# Android — future phase

Not started, and deliberately not designed yet.

Android keyboards use `InputMethodService` rather than iOS's
`UIInputViewController`. The constraints differ in ways that matter: Android
*does* expose selected text (`getSelectedText`), so the cursor-boundary
approach in `TextContextResolver` is an iOS workaround that Android should not
inherit uncritically.

What should carry over: the backend API, the prompt design, the tool set, and
the privacy commitments. What should not: the text-scope strategy.
