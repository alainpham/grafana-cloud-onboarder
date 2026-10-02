# Grafana Cloud onboarding explorer

An interactive version of the Grafana Cloud network-flow diagram. Viewers pick what they want to observe, or click any box or arrow on the diagram, and get:

- the prerequisites to line up (account-level and per use case),
- setup steps, components to deploy and firewall rules,
- links to the matching Grafana Cloud documentation,
- when it runs inside a Grafana Cloud stack, direct links into that stack's setup pages and a ready-made prompt for Grafana Assistant,
- an onboarding plan that combines all selected use cases, exportable as Markdown.

It ships as a dashboard you import into a Grafana Cloud stack. The same page also works as a standalone HTML file.

![Grafana Cloud network flows: customer assets on the left (internet and cloud sources, apps, network equipment, middleware, SQL databases, and hosts running Grafana Alloy, the PDC tunnel and a private synthetic probe) connect out to Grafana Cloud on the right (public synthetic probes, external sources, Grafana and the telemetry databases) through probe, scrape, push and query flows](grafana-cloud-network-flows.svg)

*The diagram the explorer is built on, [`grafana-cloud-network-flows.svg`](grafana-cloud-network-flows.svg).*

## Repository contents

| File | Purpose |
|---|---|
| `grafana-cloud-onboarder.html` | **The source.** A self-contained page with the diagram embedded. Edit this. |
| `grafana-cloud-network-flows.svg` | The original diagram. The page embeds it verbatim; the interactivity is a separate overlay layer. |
| `dashboard.template.json` | Dashboard layout (Grafana dashboard v2 schema) with a placeholder where the page is injected. |
| `build-dashboard.sh` | Generates the importable dashboard from the HTML and the template. |
| `grafana-cloud-onboarder.dashboard.json` | **Generated.** The dashboard to import. Rebuild it after every change to the HTML. |

## Deploy on a Grafana Cloud stack

### Prerequisites

- A Grafana Cloud stack running Grafana 12 or later. The template uses the dashboard v2 schema.
- Permission to install plugins (stack Admin) and to create dashboards (Editor or Admin).
- The **Business Text** panel plugin (`marcusolsson-dynamictext-panel`), version 6 or later.

### 1. Install the Business Text plugin

1. In your stack, go to **Administration → Plugins and data → Plugins**.
2. Search for **Business Text** and click **Install**.

The standard Text panel can't be used. On Grafana Cloud it strips scripts, SVG and form elements, so the explorer would show at most a static image. Business Text runs the panel's *After Render* JavaScript, which is what loads the explorer.

### 2. Import the dashboard

1. Go to **Dashboards → New → Import**.
2. Upload `grafana-cloud-onboarder.dashboard.json`, or paste its contents.
3. Pick a folder and click **Import**.

The dashboard's uid is `gco-onboarding-explorer`. Importing again overwrites the existing copy, which is how you deploy updates.

### 3. Check it works

Open the dashboard and confirm that:

- the use-case cards appear in the left panel and the diagram boxes highlight on hover,
- clicking a use case shows an orange **In your stack `<name>`** box under *Getting started*. That means stack detection worked.

If the panel is blank or not interactive, see [Troubleshooting](#troubleshooting).

### Share it

Share the dashboard like any other: give viewers access to its folder, or send them the dashboard link. Viewers need the Viewer role and nothing else.

## Update the content

All content lives in `grafana-cloud-onboarder.html`: use cases, prerequisites, steps, firewall rules, documentation links, stack links and Assistant prompts. They're defined as data near the top of the page's `<script>` block (`USECASES`, `NODES`, `EDGES`, `DOCS`, `GLOBAL_PREREQS`).

1. Edit `grafana-cloud-onboarder.html` and check it by opening it in a browser.
2. Rebuild the dashboard:

   ```bash
   ./build-dashboard.sh
   ```

   This needs `bash` and `jq` 1.6 or later. Optional arguments: `./build-dashboard.sh [page.html] [template.json] [output.json]`.
3. Re-import `grafana-cloud-onboarder.dashboard.json` (step 2 above).

Keep exactly one `<script>…</script>` block in the page. The build stops with an error otherwise.

### Updating the diagram

When `grafana-cloud-network-flows.svg` changes, the page has to be updated too:

- **Embedded copy:** replace the `<svg version="1.1" …>…</svg>` element in the HTML with the new file's contents, unchanged.
- **Overlay coordinates:** check `NODES[].r` (box hotspots) and `EDGES[].d` / `EDGES[].lbl` (arrow paths and label boxes). They use the SVG's own `960 × 540` coordinates. An arrow without a label box uses `lbl:null`.
- **Use cases:** add any new arrow ids to the `edges` list of the use cases they belong to.
- **New arrow colours:** a new kind of flow (for example the red *Poll* arrow) needs an entry in `FLOWTYPES`. That entry sets its name, colour and legend button.

### Changing the dashboard layout

1. Arrange the panel in Grafana and save.
2. Export the dashboard as JSON (**Export → Export as JSON**, dashboard v2 format).
3. Turn the export into the template:

   ```bash
   jq '
     .metadata = {name: .metadata.name}
     | .spec.elements["panel-1"].spec.vizConfig.spec.options.afterRender |= (
         split("\n") | "/*@@PAGE@@*/\n" + (.[2:] | join("\n")))
   ' exported.json > dashboard.template.json
   ```

   This keeps only the dashboard name in `metadata`, dropping the stack namespace, uid, versions and user annotations, so the template imports into any stack. It also swaps the two embedded `const HTML` / `const CODE` lines for the placeholder.
4. Run `./build-dashboard.sh`.

## How it works

The Business Text panel's *After Render* code creates a same-origin `<iframe>` and loads the page into it. The frame keeps the page's CSS and element ids from clashing with Grafana's.

Grafana's Content-Security-Policy (`'strict-dynamic'` with a nonce) blocks inline `<script>` tags inside that frame, but allows `eval`. Business Text needs `eval` for its own code anyway. So the build splits the page in two:

- `const HTML` holds the markup without its script and becomes the frame content.
- `const CODE` holds the script, which runs through the frame's own `Function` constructor.

The frame resizes to its content, and the dashboard panel handles scrolling.

Inside the panel, the page:

- **Detects the stack** from the dashboard URL (`<stack>.grafana.net`) and builds the setup links and the Assistant link from it.
- **Follows the Grafana theme** (light or dark) unless the viewer picks one with the page's own toggle.
- **Remembers each viewer's selection and theme** in their browser's `localStorage`. Nothing is stored server-side or shared between viewers.

### Grafana Assistant

Grafana Assistant has no documented URL parameter for pre-filling a prompt. Each **Get started with Grafana Assistant** button therefore copies a prompt written for that use case to the clipboard and opens `/a/grafana-assistant-app` in a new tab. The viewer then pastes the prompt.

## Using the standalone page

`grafana-cloud-onboarder.html` works on its own. Open it from disk, or host it on any static web server.

- **Off-stack behaviour:** outside `*.grafana.net` the stack links and Assistant buttons are hidden.
- **Previewing the stack links:** add `?stack=<name>` to the page URL to see them as they'd appear in that stack, for example `grafana-cloud-onboarder.html?stack=acme`.
- **Don't host it inside Grafana:** don't serve the raw HTML from Grafana or paste it into a Text panel. Grafana's CSP blocks its inline script there. Use the generated dashboard instead.

## Troubleshooting

| Symptom | Cause and fix |
|---|---|
| Panel shows "Panel plugin not found" | Business Text isn't installed. Install it (step 1) and reload the dashboard. |
| Diagram shows but nothing is clickable, and there are no use-case cards | The page script didn't run. Most likely an older dashboard build that used an inline `<script>`, or the HTML was pasted into a plain Text panel. Re-import the current `grafana-cloud-onboarder.dashboard.json`. |
| Red "Could not start the explorer: …" at the top of the panel | The page code threw an error. Open `grafana-cloud-onboarder.html` directly in a browser and check the console for the same error. |
| No "In your stack" box under *Getting started* | The dashboard isn't being viewed on a `*.grafana.net` URL, for example behind a custom domain. The stack links are only shown on `<stack>.grafana.net`. |
| A stack link opens a "page not found" | The app isn't installed or enabled on that stack, or its path changed. Paths are in the `stack` field of each use case and in `GLOBAL_STACK` in the HTML. |
| Import fails on an older Grafana | The template uses the dashboard v2 schema (Grafana 12 or later). |
