#!/usr/bin/env python3
"""Points every test plan at the targets the generated project actually has.

XcodeGen derives target identifiers from the project, so renaming the project
rewrites all of them. A test plan still holding the old identifier does not
fail loudly: it resolves to nothing and the run reports success having executed
no tests. This keeps the two in step so that silent pass cannot happen.

Run it after `xcodegen generate`. It is a no-op when nothing moved.
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
PLANS = ROOT / "TestPlans"

# `<uuid> /* <name> */ = {` followed by `isa = PBXNativeTarget;`. The isa line
# is what separates a target from the group that shares its name.
TARGET = re.compile(
    r"^\t\t([A-F0-9]{24}) /\* (.+?) \*/ = \{\n\t\t\tisa = PBXNativeTarget;",
    re.MULTILINE,
)


def main() -> int:
    projects = sorted(ROOT.glob("*.xcodeproj"))
    if len(projects) != 1:
        names = ", ".join(p.name for p in projects) or "none"
        print(f"expected exactly one .xcodeproj, found: {names}", file=sys.stderr)
        return 1
    project = projects[0]

    pbxproj = (project / "project.pbxproj").read_text()
    identifiers = {name: uuid for uuid, name in TARGET.findall(pbxproj)}
    if not identifiers:
        print(f"no native targets found in {project.name}", file=sys.stderr)
        return 1

    changed = False
    for plan in sorted(PLANS.glob("*.xctestplan")):
        document = json.loads(plan.read_text())
        edited = False

        for entry in document.get("testTargets", []):
            target = entry.get("target", {})
            name = target.get("name")
            if name not in identifiers:
                print(f"{plan.name}: no target named {name!r} in {project.name}", file=sys.stderr)
                return 1

            container = f"container:{project.name}"
            if target.get("containerPath") != container:
                target["containerPath"] = container
                edited = True
            if target.get("identifier") != identifiers[name]:
                target["identifier"] = identifiers[name]
                edited = True

        if edited:
            # Xcode writes these with two-space indent and a trailing newline.
            plan.write_text(json.dumps(document, indent=2, sort_keys=True) + "\n")
            print(f"updated {plan.name}")
            changed = True

    if not changed:
        print("test plans already match the project")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
