Luma guides (GitHub Actions)
Runs the iptv-org EPG collector every day at 04:00 UTC and publishes XMLTV guide files for Luma IPTV (or any player that accepts XMLTV `.xml.gz` guides):
File	Covers	Main source
`uk.xml.gz`	UK and Irish channels	sky.com (Virgin TV Go, EE, Freeview, tvireland backups)
`northamerica.xml.gz`	US/Canada movie, entertainment, news and sports channels	tvpassport.com, tvguide.com, tvtv.us (EPGTalk fills gaps)
`intl.xml.gz`	Foreign channels in the UK section (ESPN NL, Sport TV, SuperSport, beIN, Real Madrid TV, Court TV)	local sites for each country
`au.xml.gz`	Australian sport: Fox Cricket, Fox Sports 502–507, ESPN, ESPN 2, Sky Racing 1–2, Racing.com	foxtel.com.au (ontvtonight.com backup)
Each guide has a matching `*-report.csv` showing how many programmes each channel got and which site they came from.
Use the guides in Luma
Settings → Extra EPG URLs, one per line:
    https://raw.githubusercontent.com/Lumaepg/luma-epg/guide/uk.xml.gz
    https://raw.githubusercontent.com/Lumaepg/luma-epg/guide/northamerica.xml.gz
    https://raw.githubusercontent.com/Lumaepg/luma-epg/guide/intl.xml.gz
    AU https://raw.githubusercontent.com/Lumaepg/luma-epg/guide/au.xml.gz

The `AU` prefix stops Australian listings being used for same-named channels from other countries (for example ESPN). Turn on Prefer extra guides if you want these listings to replace your provider's for shared channels.
Channel ids follow one provider's naming (e.g. `BBC ONE`, `AU | FOX SPORTS 503`). Luma also matches by channel name, but if your provider names channels differently, fork the repository and edit the channel lists (below).
Make your own copy (fork)
Click Fork at the top of this page.
In your fork: Actions tab → enable workflows → Update guides → Run workflow.
When it finishes (about 10–30 minutes), your guides are on the `guide` branch of your fork. Use the links above with `Lumaepg` replaced by your GitHub username.
To change channels, edit the `$wanted` list in `make-uk-channels.ps1`, `make-na-channels.ps1`, `make-intl-channels.ps1` or `make-au-channels.ps1`. The left side is the channel id your player uses; the right side is the names guide sites use.
Test on your PC first (PowerShell 7)
Needs Git and Node.js (`winget install Git.Git` and `winget install OpenJS.NodeJS.LTS`).
    pwsh -ExecutionPolicy Bypass -File test-guide.ps1 -Region uk
    pwsh -ExecutionPolicy Bypass -File test-guide.ps1 -Region na
    pwsh -ExecutionPolicy Bypass -File test-guide.ps1 -Region intl
    pwsh -ExecutionPolicy Bypass -File test-guide.ps1 -Region au

Each run grabs one day of listings into `%USERPROFILE%\epg`. Several guide sites are collected per channel and `finish-guide.ps1` keeps the best one, so a site that breaks is covered by the next one automatically.
The `guide` branch is overwritten each day, so the repository does not grow.
Listings come from public guide websites via iptv-org/epg. This repository contains no video streams or links to paid services.
