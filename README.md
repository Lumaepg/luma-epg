# Luma guides (GitHub Actions)

Runs the iptv-org EPG collector every day and publishes guide files for Luma:

| File | Covers | Main source |
|---|---|---|
| `northamerica.xml.gz` | US/Canada movie, entertainment, news and sports channels | tvtv.us |
| `uk.xml.gz` | The provider's UK and Irish channels | sky.com (Freeview, Virgin Media backups) |
| `intl.xml.gz` | Foreign channels in the provider's UK section (ESPN NL, Sport TV, SuperSport, beIN, Real Madrid TV, Court TV) | local sites for each country |

## Test on your PC first (PowerShell 7)

Needs Git and Node.js (`winget install Git.Git` and `winget install OpenJS.NodeJS.LTS`).

    pwsh -ExecutionPolicy Bypass -File test-guide.ps1 -Region uk
    pwsh -ExecutionPolicy Bypass -File test-guide.ps1 -Region na
    pwsh -ExecutionPolicy Bypass -File test-guide.ps1 -Region intl

Each run grabs one day of listings into `%USERPROFILE%\epg`. Up to four (UK) or three (US/Canada) guide sites are collected per channel and `finish-guide.ps1` keeps whichever returned the most listings, so a site that breaks is covered by the next one automatically.

## Upload

1. Create a **public** GitHub repository (e.g. `luma-epg`).
2. Upload this folder's contents, including the hidden `.github` folder.
3. Actions tab → **Update guides** → **Run workflow** for the first run.
4. Add these lines to Luma's Extra EPG URLs:

       https://raw.githubusercontent.com/YOUR-USERNAME/luma-epg/guide/uk.xml.gz
       https://raw.githubusercontent.com/YOUR-USERNAME/luma-epg/guide/northamerica.xml.gz
       https://raw.githubusercontent.com/YOUR-USERNAME/luma-epg/guide/intl.xml.gz

The guide branch is overwritten each day, so the repository does not grow.
