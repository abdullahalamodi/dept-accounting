# Project UI and architecture rules

## Unified system design

Treat the existing design system as the source of truth for every UI change.
Before adding a widget or style, inspect and reuse the existing theme tokens,
shared widgets, and feature-level components. Keep typography, spacing, field
geometry, colors, radii, focus states, hover states, and selected states
consistent across the product. Extend a reusable component when the behavior
belongs to the system; create a new component only when no existing component
fits or the behavior is genuinely distinct. When a pattern appears more than
once, extract and reuse it instead of maintaining page-specific copies.

## Testing

add tests as minimal as possible, and only when it is necessary to test a specific behavior.

## flutter stack

- go_router: for routing and navigation
- changenotifier: for state management
- flutter mvvm: for state management and separation of concerns
- dart_mappable for class generation and serialization
- feature based architecture: for feature isolation and folders structure.
