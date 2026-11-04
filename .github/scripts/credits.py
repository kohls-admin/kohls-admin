"""
Regenerates the About page's credits data (src/Client/About/Contributions.luau) from
Credits.luau's people:

- `recent`: each GitHub login's commits in the window (author date, inclusive of the window's first instant) across
  the 1.0 repositories. A credited person with at least the threshold is an **active contributor**; the page orders
  them by these counts. The threshold and the window's length are Credits.luau's `active = { commits, days }`, which
  Order.luau reads too: this script parses them from there, so the rule has one home.
- `names`: each credited Roblox id's username, display name and verified badge. Everyone else is listed by
  @username, alphabetically.

The module is rewritten only when what the page shows changes: the active contributors or their order, or the plain
list's order or usernames (About/Order.luau). A count or display name that changes nothing visible leaves the file
alone, so the weekly workflow has nothing to commit; the page refreshes the chips' names live.

    python3 .github/scripts/credits.py           # rewrite the module if the page would change; list unmapped logins
    python3 .github/scripts/credits.py --check   # exit 1 when the page would change (network; run explicitly)
    python3 .github/scripts/credits.py --force   # rewrite the module with fresh data regardless

The window and the order here, and the order in Order.luau, are checked against test/unit/CreditsOrder.json:
this script checks the window (an injected "now", a commit on the boundary, someone dropping out) and the order on
every run; ClientAndUI.spec checks Order.luau's order against the same fixture's window counts. The window is computed
only here, so the page can't disagree with it.

GitHub: the REST commits API (`since` the window's start; one request per 100 commits) with GITHUB_TOKEN (or
GH_TOKEN, or `gh auth token`) when there is one, and the contributors API to list logins that aren't credited. A
repository that doesn't exist (yet) or is empty counts as no commits. Bots and commits not linked to a GitHub account
are left out. Roblox: users.roblox.com's batch lookup. Standard library only.
"""

import argparse
import datetime
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.request

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
CREDITS_FILE = os.path.join(ROOT, "src/Client/About/Credits.luau")
TARGET_FILE = os.path.join(ROOT, "src/Client/About/Contributions.luau")
FIXTURE_FILE = os.path.join(ROOT, "test/unit/CreditsOrder.json")

REPOS = [
    "kohls-admin/kohls-admin",
    "kohltastrophe/flux",
    "kohltastrophe/Z",
    "kohls-admin/building-tools",
]

USER_AGENT = "kohls-admin-credits"
# users.roblox.com takes at most 100 ids a request.
ROBLOX_BATCH = 100


def github_token():
    for name in ("GITHUB_TOKEN", "GH_TOKEN"):
        if os.environ.get(name):
            return os.environ[name]
    try:
        out = subprocess.run(["gh", "auth", "token"], capture_output=True, text=True, timeout=10)
        if out.returncode == 0 and out.stdout.strip():
            return out.stdout.strip()
    except (OSError, subprocess.SubprocessError):
        pass
    return None


def request(url, token=None, body=None):
    headers = {"User-Agent": USER_AGENT, "Accept": "application/json"}
    data = None
    if token:
        headers["Authorization"] = f"Bearer {token}"
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, headers=headers)
    with urllib.request.urlopen(req, timeout=30) as response:
        if response.status == 204:
            return []
        return json.load(response)


def pages(url, token):
    """Every item of a paginated GitHub list; nothing for a missing (404) or empty (409) repository."""
    page = 1
    while True:
        try:
            batch = request(f"{url}&per_page=100&page={page}", token)
        except urllib.error.HTTPError as e:
            if e.code in (404, 409):
                print(f"{url.split('?')[0]}: {e.code}, counted as nothing", file=sys.stderr)
                return
            raise
        if not batch:
            return
        yield from batch
        if len(batch) < 100:
            return
        page += 1


def is_bot(user):
    return user.get("type") == "Bot" or user.get("login", "").endswith("[bot]")


def parse_time(text):
    return datetime.datetime.fromisoformat(text.replace("Z", "+00:00"))


def iso(moment):
    return moment.astimezone(datetime.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def commit_dates(token, since):
    """GitHub login -> the author dates of their commits since `since` across REPOS (bots and unlinked left out)."""
    dates = {}
    unlinked = 0
    for repo in REPOS:
        url = f"https://api.github.com/repos/{repo}/commits?since={iso(since)}"
        for item in pages(url, token):
            author = item.get("author")
            if not author or not author.get("login"):
                unlinked += 1
                continue
            if is_bot(author):
                continue
            login = author["login"]
            key = next((k for k in dates if k.lower() == login.lower()), login)
            dates.setdefault(key, []).append(item["commit"]["author"]["date"])
    if unlinked:
        print(f"{unlinked} commits in the window aren't linked to a GitHub account (left out)", file=sys.stderr)
    return dates


def all_time_logins(token):
    """Every GitHub login with a commit in REPOS (bots left out): for listing the ones nobody credits."""
    logins = {}
    for repo in REPOS:
        for person in pages(f"https://api.github.com/repos/{repo}/contributors?anon=0", token):
            if person.get("login") and not is_bot(person):
                logins[person["login"].lower()] = person["login"]
    return logins


def credited():
    """(people [(id, GitHub login or None)] in file order, the special thanks id)."""
    with open(CREDITS_FILE, encoding="utf-8") as f:
        source = f.read()
    people_at = source.index("people = {")
    special_at = source.index("specialThanks = {")
    body = source[people_at:special_at]
    entries = list(re.finditer(r"\bId\s*=\s*(\d+)", body))
    people = []
    for at, entry in enumerate(entries):
        # An entry's fields run from its Id to the next entry's.
        stop = entries[at + 1].start() if at + 1 < len(entries) else len(body)
        login = re.search(r'\bGitHub\s*=\s*"([^"]+)"', body[entry.end() : stop])
        people.append((int(entry.group(1)), login.group(1) if login else None))
    special = int(re.search(r"\bId\s*=\s*(\d+)", source[special_at:]).group(1))
    return people, special


def roblox_names(ids):
    """Roblox id -> (username, display name, verified badge)."""
    names = {}
    for start in range(0, len(ids), ROBLOX_BATCH):
        chunk = ids[start : start + ROBLOX_BATCH]
        result = request("https://users.roblox.com/v1/users", body={"userIds": chunk, "excludeBannedUsers": False})
        for user in result.get("data", []):
            names[int(user["id"])] = (
                user["name"],
                user.get("displayName") or user["name"],
                bool(user.get("hasVerifiedBadge")),
            )
    return names


# --- The window and the order: Order.luau's order, step for step. -----------------------------------------------


def rule():
    """Credits.luau's `active = { commits = N, days = M }`: (the commits that make someone active, the window's days)."""
    with open(CREDITS_FILE, encoding="utf-8") as f:
        source = f.read()
    found = re.search(r"\bactive\s*=\s*\{\s*commits\s*=\s*(\d+),\s*days\s*=\s*(\d+)\s*\}", source)
    if not found:
        sys.exit(f"no `active = {{ commits = N, days = M }}` in {os.path.relpath(CREDITS_FILE, ROOT)}")
    return int(found.group(1)), int(found.group(2))


ACTIVE_COMMITS, WINDOW_DAYS = rule()


def window(dates, now, days=WINDOW_DAYS):
    """login -> commits whose author date is within `days` before `now` (the window's first instant included)."""
    since = now - datetime.timedelta(days=days)
    recent = {}
    for login, stamps in dates.items():
        count = sum(1 for stamp in stamps if since <= parse_time(stamp) <= now)
        if count > 0:
            recent[login] = count
    return recent


def lower(text):
    """Luau's string.lower: ASCII letters only, as bytes (Luau compares strings bytewise)."""
    return text.encode("utf-8").lower()


def commits_of(recent):
    totals = {}
    for login, count in recent.items():
        totals[lower(login)] = totals.get(lower(login), 0) + count
    return totals


def active(people, recent, names):
    """Order.active: the people with at least ACTIVE_COMMITS commits in the window, most first, then by name."""
    totals = commits_of(recent)

    def commits(person):
        return totals.get(lower(person[1]), 0) if person[1] else 0

    def key(person):
        named = names.get(person[0])
        return (
            -commits(person),
            0 if named else 1,
            lower(named[1]) if named else b"",
            lower(named[0]) if named else b"",
            person[0],
        )

    return [person[0] for person in sorted((p for p in people if commits(p) >= ACTIVE_COMMITS), key=key)]


def plain(people, recent, names):
    """Order.plain: everyone else, by username (case-insensitive), then id; a nameless credit last, by id."""
    shown = set(active(people, recent, names))

    def key(person):
        named = names.get(person[0])
        return (0 if named else 1, lower(named[0]) if named else b"", person[0])

    return [person[0] for person in sorted((p for p in people if p[0] not in shown), key=key)]


def visible(people, special, recent, names):
    """What the page shows that this data decides: the active ids in order, the plain list's (id, username) in
    order, and the special thanks."""
    return (
        active(people, recent, names),
        [(user_id, names[user_id][0] if user_id in names else None) for user_id in plain(people, recent, names)],
        special,
    )


def self_test():
    """The shared fixture: the window from dated commits, then both orders (ClientAndUI.spec checks the orders too)."""
    with open(FIXTURE_FILE, encoding="utf-8") as f:
        fixture = json.load(f)
    recent = window(fixture["commits"], parse_time(fixture["now"]))
    problems = []
    if recent != fixture["recent"]:
        problems.append(f"window: {recent}")
    people = [(person["Id"], person.get("GitHub")) for person in fixture["people"]]
    names = {entry[0]: (entry[1], entry[2], False) for entry in fixture["names"]}
    if active(people, fixture["recent"], names) != fixture["active"]:
        problems.append(f"active: {active(people, fixture['recent'], names)}")
    if plain(people, fixture["recent"], names) != fixture["plain"]:
        problems.append(f"plain: {plain(people, fixture['recent'], names)}")
    if problems:
        print(f"credits.py disagrees with {os.path.relpath(FIXTURE_FILE, ROOT)}: {'; '.join(problems)}", file=sys.stderr)
        sys.exit(2)


# --- The generated module. ---------------------------------------------------------------------------------------


def luau_string(text):
    return json.dumps(text, ensure_ascii=False)


def render(recent, names):
    lines = [
        "--!strict",
        "-- generated by .github/scripts/credits.py, do not edit",
        "--[[",
        f"\tThe credits' data: `recent` is each GitHub login's commits in the {WINDOW_DAYS} days before this was generated,",
        f"\tacross Kohl's Admin, Flux, Z and Building Tools (a credited login with {ACTIVE_COMMITS}+ is active); `names`",
        "\tis each credited Roblox id's username, display name and verified badge then. Rewritten only when what the",
        "\tpage shows changes, so counts and display names can be older than that.",
        "]]",
        "export type Contributions = {",
        "\trecent: { [string]: number },",
        "\tnames: { [number]: { name: string, displayName: string, verified: boolean } },",
        "}",
        "",
        "local contributions: Contributions = {",
        "\trecent = {",
    ]
    for login, count in sorted(recent.items(), key=lambda item: (-item[1], item[0].lower())):
        lines.append(f"\t\t[{luau_string(login)}] = {count},")
    lines.append("\t},")
    lines.append("\tnames = {")
    for user_id in sorted(names):
        name, display, verified = names[user_id]
        lines.append(
            f"\t\t[{user_id}] = {{ name = {luau_string(name)}, displayName = {luau_string(display)}, "
            f"verified = {'true' if verified else 'false'} }},"
        )
    lines.append("\t},")
    lines.append("}")
    lines.append("")
    lines.append("return table.freeze(contributions)")
    return "\n".join(lines) + "\n"


def committed():
    """The committed module's (recent, names), or None when there is none (or it predates `recent`)."""
    try:
        with open(TARGET_FILE, encoding="utf-8") as f:
            source = f.read()
    except FileNotFoundError:
        return None
    if "\trecent = {" not in source:
        return None
    string = r'"(?:[^"\\]|\\.)*"'
    recent = {json.loads(m.group(1)): int(m.group(2)) for m in re.finditer(rf"\[({string})\] = (\d+),", source)}
    names = {
        int(m.group(1)): (json.loads(m.group(2)), json.loads(m.group(3)), m.group(4) == "true")
        for m in re.finditer(
            rf"\[(\d+)\] = {{ name = ({string}), displayName = ({string}), verified = (true|false) }},", source
        )
    }
    return recent, names


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--check", action="store_true", help="exit 1 when the page would change")
    parser.add_argument("--force", action="store_true", help="rewrite the module even if the page wouldn't change")
    args = parser.parse_args()

    self_test()
    people, special = credited()
    ids = sorted({user_id for user_id, _ in people} | {special})
    logins = {login.lower() for _, login in people if login}

    token = github_token()
    now = datetime.datetime.now(datetime.timezone.utc)
    since = now - datetime.timedelta(days=WINDOW_DAYS)
    recent = window(commit_dates(token, since), now)
    names = roblox_names(ids)
    missing = [user_id for user_id in ids if user_id not in names]
    if missing:
        print(f"Roblox ids with no user: {', '.join(map(str, missing))}", file=sys.stderr)

    everyone = all_time_logins(token)
    unmapped = sorted((login for key, login in everyone.items() if key not in logins), key=str.lower)
    if unmapped:
        print("GitHub logins with no credit (add `GitHub = \"<login>\"` to their Credits.luau entry):")
        for login in unmapped:
            print(f"  {login}" + (f" ({recent[login]} in the window)" if login in recent else ""))

    shown = {user_id for user_id in active(people, recent, names)}
    print(f"Active contributors ({len(shown)}: {ACTIVE_COMMITS}+ commits since {iso(since)}):")
    totals = commits_of(recent)
    for user_id in active(people, recent, names):
        login = next(login for person_id, login in people if person_id == user_id)
        print(f"  {login}: {totals[lower(login)]}")

    target = os.path.relpath(TARGET_FILE, ROOT)
    fresh = visible(people, special, recent, names)
    current = committed()
    changed = current is None or visible(people, special, *current) != fresh
    if changed and current is not None:
        before = visible(people, special, *current)
        for part, label in ((0, "the active contributors"), (1, "the contributors list"), (2, "the special thanks")):
            if before[part] != fresh[part]:
                print(f"{label}: changed")

    if args.check:
        if changed:
            print(f"{target} is out of date (the credits page would change): run .github/scripts/credits.py", file=sys.stderr)
            sys.exit(1)
        print(f"{target} gives the current credits page")
        return

    if not changed and not args.force:
        print(f"The credits page is unchanged; {target} left as it is")
        return
    with open(TARGET_FILE, "w", encoding="utf-8") as f:
        f.write(render(recent, names))
    print(f"Wrote {len(recent)} logins with commits in the window and {len(names)} names to {target}")


if __name__ == "__main__":
    main()
