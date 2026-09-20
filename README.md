# Omarchy Hacker News

An [Omarchy](https://omarchy.org/) shell plugin (service + bar-widget) that
puts Hacker News in the bar: a rotating headline pill with a story popup.

Built on the official [HN API](https://github.com/HackerNews/API) — no key, no
rate limit, fetched live with `curl`.

## Features

- **Bar pill** — `HN <feed> <headline> ▲score`, titles cycle every few seconds.
- **Popup panel** — scrollable list with title, score, author, comment count and
  age. Feed tabs: **Top / Best / New**.
- **Click actions** — click a story to open the article; `Shift`+click or
  middle-click opens the HN discussion thread. Ask/Show/job stories without a
  URL always open the thread.
- **Cache + retry** — stories stay visible while offline; failures retry with
  backoff (1m → 60m).

## Install

```bash
omarchy plugin add https://github.com/iampoul/omanews --enable
omarchy restart shell
```

Or clone into this repo and add the local path:

```bash
omarchy plugin add file:///home/iampoul/Work/omanews --enable
```

## Remove

```bash
omarchy plugin remove io.github.iampoul.hackernews
omarchy restart shell
```

This removes the plugin; your `shell.json` bar layout is left untouched.

## Requirements

- `curl` and `jq` on `PATH` — the plugin fetches the HN API via external
  processes (`fetch-feed.sh`, `curl` + `jq`), so no in-process networking is
  used. Everything else is [Quickshell](https://quickshell.io/) in-tree QML.
- Uses the official [HN API](https://github.com/HackerNews/API). No API key.

## Usage

| Input | Action |
| --- | --- |
| Click pill | Open/close the story popup |
| `Shift`+click pill | Open current story's HN thread |
| Middle-click pill | Open current story (article) |
| `Shift`+middle pill | Cycle feed Top → Best → New |
| Click story | Open article (thread if no URL) |
| `Shift`/middle-click story | Open HN thread |
| Header refresh button | Force a refetch |

Move the widget with `omarchy bar move io.github.iampoul.hackernews --section <left|center|right>`.

## Settings

Inline entry keys in `~/.config/omarchy/shell.json` (defaults in `manifest.json`):

| Key | Default | Meaning |
| --- | --- | --- |
| `feed` | `top` | Initial feed: `top`, `best`, `new` |
| `refreshMinutes` | `5` | How often to poll the API |
| `tickerSeconds` | `6` | Headline rotation period |
| `storyCount` | `30` | Stories fetched per feed |

## Files

```
manifest.json   plugin manifest (service + bar-widget)
Service.qml     background poller, cache, retry
Model.js        parsing/formatting helpers (pure JS)
BarWidget.qml   bar pill + headline ticker
Panel.qml       story popup with feed tabs
fetch-feed.sh   curl+jq HN API fetch (top/best/new + story details)
```

## Development

Edit files under `~/.config/omarchy/plugins/io.github.iampoul.hackernews/`
(they hot-reload on save) or edit this repo and `git pull` inside the plugin
folder. Validate with:

```bash
omarchy plugin validate .
```

MIT.