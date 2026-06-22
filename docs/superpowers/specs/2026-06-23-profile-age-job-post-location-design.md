# Profile Age and Job Post Form Fixes

## Scope

Implement exactly three changes in the Flutter mobile app:

1. Require candidates to be at least 18 years old when updating their date of birth.
2. Remove the horizontal overflow in the job-post work-experience requirement card.
3. Replace the free-text province/city field in the job-post form with a searchable Vietnam province/city selector.

## Date of Birth Validation

- Add a reusable, deterministic age check that accepts the birth date and a reference date.
- A person is eligible only when their 18th birthday is on or before the reference date.
- For a February 29 birth date whose 18th year is not a leap year, the normalized 18th birthday is March 1.
- The date picker must use the latest eligible birth date as its maximum selectable date.
- The form validator and account update controller must reject an under-18 date with the Vietnamese message `Bạn phải đủ 18 tuổi`.
- Existing valid dates and the current profile update flow remain unchanged.

## Work Experience Overflow

- Keep the existing requirement card structure and styling.
- Make shared dropdowns expand to the available width.
- Render selected dropdown labels on one line with ellipsis when space is limited.
- Keep the dropdown arrow, prefix icon, and all existing experience values functional.

## Searchable Province/City Selector

- Reuse the project's existing `LocationService` instead of adding a dependency.
- Load Vietnam province/city names when the create/edit job-post screen starts.
- Tapping the province/city field opens a bottom sheet with a search box and filtered list.
- Selecting an item updates the existing city controller so the saved `location.city` schema is unchanged.
- In edit mode, preserve the stored city value even while the remote list is loading.
- Show loading, empty-result, and retry states. The field remains required.

## Tests and Verification

- Unit-test the exact 18th-birthday boundary, an under-18 date, an older date, and leap-day behavior.
- Widget-test that the shared dropdown can render a long selected label in narrow width without overflow.
- Isolate province/city filtering in a helper and unit-test accent-insensitive search and empty results.
- Run targeted Flutter tests, targeted analysis for changed files, formatting, and `git diff --check`.

## Out of Scope

- District/ward cascading selectors.
- Changes to shipping-address screens.
- New third-party dropdown packages.
- Unrelated visual redesign or data-schema changes.
