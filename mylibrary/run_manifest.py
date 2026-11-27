# ---------------------------------------------------------------------------
# run_manifest.py
# Writes a plain-text "run manifest" next to a script's outputs, so that days
# later you can tell which code, inputs and settings produced them.
#
# Standard library only and does NOT import arcpy, so it is safe to use from
# orchestrators and from ArcGIS Pro workers alike. Import it as a top-level
# module (not through the mylibrary package, whose __init__ imports arcpy):
#
#     import sys
#     sys.path.append(r"S:\particulates\data_processing\dofiles_la\dofiles\mylibrary")
#     import run_manifest
#
#     m = run_manifest.start(
#         outdir=r"..\..\..\data\VanDonkelar_annual\generated",
#         inputs=nc_files,                     # list of paths (files or folders)
#         expected="3 tifs, values 0-200 ug/m3",
#         issue="laldecol/dofiles#40")         # optional: the GitHub issue
#     ...  do the work  ...
#     m.finish(outputs=out_tifs)
#
# Or as a context manager, which records a crash as status: failed:
#
#     with run_manifest.start(outdir, inputs=..., expected=...) as m:
#         ...
#         m.outputs += out_tifs
#
# Files written in outdir:
#   run_manifest.txt          latest run (overwritten each run; written at
#                             start with status: running, rewritten at finish)
#   run_manifest_history.txt  every run appended, newest last
#
# Created 2026-11-27.
# ---------------------------------------------------------------------------

import datetime, getpass, hashlib, os, platform, socket, subprocess, sys, traceback

HASH_MAX_BYTES = 200 * 1024 * 1024   # md5 only files up to 200 MB by default


def _now():
    return datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")


def _find_git_dir(start):
    d = os.path.abspath(start)
    while True:
        if os.path.isdir(os.path.join(d, ".git")):
            return d
        parent = os.path.dirname(d)
        if parent == d:
            return None
        d = parent


def _read_head_without_git(repo):
    """Commit and branch from .git files, for machines without git on PATH."""
    gitdir = os.path.join(repo, ".git")
    try:
        with open(os.path.join(gitdir, "HEAD")) as f:
            head = f.read().strip()
        if not head.startswith("ref:"):
            return head, "(detached)"
        ref = head[4:].strip()
        branch = ref.replace("refs/heads/", "")
        reffile = os.path.join(gitdir, *ref.split("/"))
        if os.path.exists(reffile):
            with open(reffile) as f:
                return f.read().strip(), branch
        packed = os.path.join(gitdir, "packed-refs")
        if os.path.exists(packed):
            with open(packed) as f:
                for line in f:
                    parts = line.strip().split(" ")
                    if len(parts) == 2 and parts[1] == ref:
                        return parts[0], branch
        return "unknown", branch
    except OSError:
        return "unknown", "unknown"


def git_info(path):
    """Return dict with repo, commit, branch, dirty (list of changed files or note)."""
    repo = _find_git_dir(path)
    if repo is None:
        return {"repo": "(not in a git repo)", "commit": "unknown",
                "branch": "unknown", "dirty": "unknown"}
    info = {"repo": repo}
    try:
        def g(*args):
            return subprocess.run(["git", "-C", repo] + list(args), capture_output=True,
                                  text=True, timeout=30).stdout.strip()
        info["commit"] = g("rev-parse", "HEAD") or "unknown"
        info["branch"] = g("rev-parse", "--abbrev-ref", "HEAD") or "unknown"
        changed = [l for l in g("status", "--porcelain", "--untracked-files=no").splitlines() if l]
        info["dirty"] = "no" if not changed else "YES: " + "; ".join(c.strip() for c in changed[:20]) \
            + (" ..." if len(changed) > 20 else "")
    except (OSError, subprocess.SubprocessError):
        info["commit"], info["branch"] = _read_head_without_git(repo)
        info["dirty"] = "unknown (git not on PATH)"
    return info


def describe_file(path, hash_files=True):
    """One line: path | size | modified | md5 (or reason it was skipped)."""
    if not os.path.exists(path):
        return "%s | MISSING" % path
    if os.path.isdir(path):
        n = sum(len(fs) for _, _, fs in os.walk(path))
        return "%s | folder, %d files" % (path, n)
    st = os.stat(path)
    mtime = datetime.datetime.fromtimestamp(st.st_mtime).strftime("%Y-%m-%d %H:%M:%S")
    line = "%s | %s bytes | modified %s" % (path, format(st.st_size, ","), mtime)
    if hash_files and st.st_size <= HASH_MAX_BYTES:
        h = hashlib.md5()
        with open(path, "rb") as f:
            for chunk in iter(lambda: f.read(1 << 20), b""):
                h.update(chunk)
        line += " | md5 " + h.hexdigest()
    elif hash_files:
        line += " | md5 skipped (>200 MB)"
    return line


class Manifest(object):
    def __init__(self, outdir, inputs=None, expected="", issue="", note="",
                 script=None, hash_files=True):
        self.outdir = os.path.abspath(outdir)
        self.inputs = list(inputs or [])
        self.expected = expected
        self.issue = issue
        self.note = note
        self.hash_files = hash_files
        self.script = os.path.abspath(script or (sys.argv[0] if sys.argv and sys.argv[0] else os.getcwd()))
        self.command = " ".join([sys.executable] + sys.argv)
        self.started = _now()
        self._t0 = datetime.datetime.now()
        self.git = git_info(os.path.dirname(self.script) if os.path.isfile(self.script) else self.script)
        self.outputs = []
        self.status = "running"
        self.finished = ""
        self.error = ""
        os.makedirs(self.outdir, exist_ok=True)
        self._input_lines = [describe_file(p, hash_files) for p in self.inputs]
        self._write(final=False)

    def _text(self):
        L = []
        L.append("=" * 78)
        L.append("RUN MANIFEST")
        L.append("status:      %s" % self.status)
        L.append("started:     %s" % self.started)
        if self.finished:
            mins = (datetime.datetime.now() - self._t0).total_seconds() / 60.0
            L.append("finished:    %s  (%.1f min)" % (self.finished, mins))
        L.append("script:      %s" % self.script)
        L.append("command:     %s" % self.command)
        L.append("issue:       %s" % (self.issue or "-"))
        L.append("git repo:    %s" % self.git["repo"])
        L.append("git commit:  %s" % self.git["commit"])
        L.append("git branch:  %s" % self.git["branch"])
        L.append("uncommitted: %s" % self.git["dirty"])
        L.append("machine:     %s / %s / %s" % (socket.gethostname(), getpass.getuser(), platform.platform()))
        L.append("python:      %s" % sys.version.split()[0])
        L.append("expected:    %s" % (self.expected or "-"))
        if self.note:
            L.append("note:        %s" % self.note)
        L.append("inputs:")
        L.extend("  " + s for s in (self._input_lines or ["-"]))
        L.append("outputs:")
        if self.outputs:
            L.extend("  " + describe_file(p, self.hash_files) for p in self.outputs)
        else:
            L.append("  -")
        if self.error:
            L.append("error:")
            L.extend("  " + l for l in self.error.rstrip().splitlines())
        L.append("")
        return "\n".join(L)

    def _write(self, final):
        text = self._text()
        with open(os.path.join(self.outdir, "run_manifest.txt"), "w") as f:
            f.write(text)
        if final:
            with open(os.path.join(self.outdir, "run_manifest_history.txt"), "a") as f:
                f.write(text + "\n")

    def finish(self, outputs=None, status="ok", note=None):
        if outputs:
            self.outputs.extend(outputs)
        if note:
            self.note = (self.note + " | " if self.note else "") + note
        self.status = status
        self.finished = _now()
        self._write(final=True)
        return os.path.join(self.outdir, "run_manifest.txt")

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        if exc_type is not None:
            self.error = "".join(traceback.format_exception(exc_type, exc, tb))
            self.finish(status="failed")
        elif self.status == "running":
            self.finish()
        return False


def start(outdir, inputs=None, expected="", issue="", note="", script=None, hash_files=True):
    """Write run_manifest.txt (status: running) in outdir and return a Manifest."""
    return Manifest(outdir, inputs, expected, issue, note, script, hash_files)
