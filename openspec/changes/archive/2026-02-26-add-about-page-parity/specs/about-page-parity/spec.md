## ADDED Requirements

### Requirement: About Page Content Parity (IMDb/TMDB Excluded)
The app MUST provide an About page whose information architecture and legal/contact content matches `cinemore-apple` About page, except IMDb-related and TMDB-related sections which SHALL be excluded.

#### Scenario: About page renders required content
- **WHEN** the About page is presented
- **THEN** it MUST display app icon, app version/build, contact email, privacy policy link, third-party license link, EULA link, copyright text, and ICP filing text
- **AND** it MUST NOT display IMDb-related branding, text, or links
- **AND** it MUST NOT display TMDB-related branding, disclaimer text, or links

### Requirement: About Icon Uses CinePlayer Branding
The About page MUST use `CinePlayerIcon` as the primary app icon visual.

#### Scenario: Primary icon is CinePlayerIcon
- **WHEN** the About page header is rendered
- **THEN** the icon shown at the top MUST be loaded from `CinePlayerIcon`

### Requirement: macOS About Entry From Application Menu
On macOS, the app MUST expose a menu entry equivalent to cinemore's About entry and open a dedicated About window from that menu action.

#### Scenario: User opens About from macOS app menu
- **WHEN** the user clicks the app menu "关于"
- **THEN** the app MUST open a dedicated About window containing the About page content
